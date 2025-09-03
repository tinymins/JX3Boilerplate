# -*- coding: utf-8 -*-
# pip3 install semver luadata

"""
自动化打包发布脚本

说明：
    本脚本负责打包、压缩、生成差异包以及发布前相关操作。如需发布，需要在stable分支下保证工作区干净！
"""

import codecs
import os
import re
import semver
import shutil
import time
from typing import Dict, Any, Optional, List

import luadata
import plib.git as git
import plib.utils as utils
from plib.environment import (
    get_current_packet_id,
    get_interface_path,
    get_packet_path,
    get_packet_dist_path,
)
from plib.assert_version import update_assert_version_for_changed_addons
from plib.language.converter import Converter


def __copy_non_build_files(addon: str) -> None:
    """
    复制子插件目录下除 *.lua 与info配置文件之外的所有文件到构建目录，
    并保持原有目录结构。

    参数：
        addon: 子插件目录名称
    """
    addon_dist_path: str = os.path.join(get_packet_dist_path(), addon)
    # 遍历子插件目录下所有文件
    for root, dirs, files in os.walk(addon):
        # 计算当前目录路径相对于子插件根目录的相对路径
        rel_path: str = os.path.relpath(root, addon)
        for file in files:
            # 跳过.lua文件
            if file.endswith(".lua"):
                continue
            # 插件根目录下的 info.ini 与 info.ini.zh_TW 文件跳过
            if os.path.abspath(root) == os.path.abspath(addon) and file in [
                "info.ini",
                "info.ini.zh_TW",
            ]:
                continue
            # 构造目标目录路径，保持原有结构
            dest_dir: str = (
                os.path.join(addon_dist_path, rel_path)
                if rel_path != "."
                else addon_dist_path
            )
            os.makedirs(dest_dir, exist_ok=True)
            shutil.copy2(os.path.join(root, file), os.path.join(dest_dir, file))


def __build_addon(packet: str, addon: str, time_tag: str) -> None:
    """
    处理子插件源码构建与合并。
    主要步骤：
      1. 读取 info.ini 中定义的 Lua 入口文件列表；
      2. 预处理源码（移除调试代码、嵌入敏感数据等）；
      3. 生成中间文件和配置（使用squishy工具构建合并）；
      4. 插入模块加载代码，并更新 info.ini 文件。

    参数：
        packet: 包标识（暂未使用，可用于后续扩展）
        addon: 子插件目录名称
    """
    print("--------------------------------")
    print("正在构建子插件：%s" % addon)
    file_count: int = 0
    converter: Converter = Converter("zh-TW")
    srcname: str = "src." + time_tag + ".lua"

    # 尝试加载敏感数据（如果存在）
    try:
        secret: Dict[str, Any] = luadata.read("secret.jx3dat") or {}
    except Exception:
        secret = {}

    # 准备输出目录以及临时目录
    packet_dist_path: str = os.path.join(get_packet_dist_path(), addon)
    dist_dir: str = os.path.join(packet_dist_path, "dist")
    os.makedirs(dist_dir, exist_ok=True)

    # 生成squishy工具所需的配置文件
    with open("squishy", "w", encoding="utf-8") as squishy:
        # 输出目标文件路径相对于工作区根目录（替换反斜杠）
        output_path: str = os.path.relpath(packet_dist_path, os.getcwd()).replace(
            "\\", "/"
        )
        squishy.write(f'Output "./{output_path}/{srcname}"\n')
        # 读取 info.ini 中定义的 lua 模块入口信息
        info_ini_path: str = os.path.join(addon, "info.ini")
        with open(info_ini_path, "r", encoding="gbk") as f_info:
            for line in f_info:
                parts: List[str] = line.strip().split("=")
                # 处理以 "lua_" 开头的项
                if parts and parts[0].startswith("lua_"):
                    # 如已有构建文件（如 src.*.lua），则跳过以免重复构建
                    if parts[1].startswith("src.") and parts[1].endswith(".lua"):
                        print("已构建，无需重复处理...")
                        return
                    # 新增模块：增加计数，生成临时文件
                    file_count += 1
                    source_file: str = os.path.join(addon, parts[1].replace("\\", "/"))
                    dist_file: str = os.path.join(dist_dir, f"{file_count}.lua")
                    try:
                        source_code: str = codecs.open(
                            source_file, "r", encoding="gbk"
                        ).read()
                    except Exception as e:
                        utils.exit_with_message(f"读取文件 {source_file} 失败：{e}")
                    # 删除包含 #DEBUG 标记的调试代码行和代码块
                    source_code = re.sub(
                        r"(?is)[^\n]*--\[\[#DEBUG LINE\]\][^\n]*\n?", "", source_code
                    )
                    source_code = re.sub(
                        r"(?is)\n\s*--\[\[#DEBUG BEGIN\]\].*?--\[\[#DEBUG END\]\]\n",
                        "\n",
                        source_code,
                    )
                    source_code = re.sub(
                        r"(?is)--\[\[#DEBUG BEGIN\]\].*?--\[\[#DEBUG END\]\]",
                        "",
                        source_code,
                    )
                    # 嵌入敏感数据（将 X.SECRET 或 addon.SECRET 中对应key的值替换为序列化结果）
                    for k, v in secret.items():
                        serialized: str = luadata.serialize(v, encoding="gbk")
                        pattern1: str = (
                            rf'\b(X|{re.escape(addon)})\.SECRET\[\s*"{re.escape(k)}"\s*\]'
                        )
                        pattern2: str = (
                            rf"\b(X|{re.escape(addon)})\.SECRET\[\s*'{re.escape(k)}'\s*\]"
                        )
                        pattern3: str = (
                            rf"\b(X|{re.escape(addon)})\.SECRET\.{re.escape(k)}\b"
                        )
                        source_code = re.sub(pattern1, serialized, source_code)
                        source_code = re.sub(pattern2, serialized, source_code)
                        source_code = re.sub(pattern3, serialized, source_code)
                    # 保存预处理后的代码至临时文件
                    codecs.open(dist_file, "w", encoding="gbk").write(source_code)
                    # 添加squishy配置：关联模块号与临时文件路径
                    rel_dist_file: str = os.path.relpath(
                        dist_file, os.getcwd()
                    ).replace("\\", "/")
                    squishy.write(f'Module "{file_count}" "{rel_dist_file}"\n')

    # 调用squishy工具合并构建（使用minify full压缩级别）
    utils.read_popen_output('lua "./!src-dist/tools/react/squish" --minify-level=full')
    # 删除临时生成的squishy配置文件
    os.remove("squishy")

    # 插入模块加载代码到构建合并后的目标文件中
    out_file: str = os.path.join(packet_dist_path, srcname)
    try:
        with open(out_file, "r+", encoding="gbk") as src:
            content: str = src.read()
            src.seek(0, 0)
            # 插入预加载表定义
            src.write("local package = { preload = {} }\n" + content)
        with open(out_file, "a", encoding="gbk") as src:
            mod_list: str = ",".join([f"'{i}'" for i in range(1, file_count + 1)])
            # 循环加载各模块
            src.write("\nfor _, k in ipairs({")
            src.write(mod_list)
            src.write("}) do package.preload[k]() end\n")
            src.write(f'Log("[ADDON] Module {addon} v{time_tag} loaded.")')
    except Exception as e:
        utils.exit_with_message(f"更新构建文件 {out_file} 失败：{e}")

    print("构建完成。")

    # 更新 info.ini 文件，将 lua_0 的入口文件名改为构建后的文件名
    info_content: str = ""
    with codecs.open(info_ini_path, "r", encoding="gbk") as f_info:
        for line in f_info:
            parts = line.split("=")
            if parts and parts[0].startswith("lua_"):
                if parts[0] == "lua_0":
                    info_content += f"lua_0={srcname}\n"
            else:
                info_content += line
    target_info: str = os.path.join(packet_dist_path, "info.ini")
    with codecs.open(target_info, "w", encoding="gbk") as f_target:
        f_target.write(info_content)
    # 同时生成繁体中文 info 配置文件（通过转换器转换编码）
    with codecs.open(
        os.path.join(packet_dist_path, "info.ini.zh_TW"), "w", encoding="utf8"
    ) as f_target_tw:
        f_target_tw.write(converter.convert(info_content))
    print("info.ini 更新完成。")


def __build(packet: str) -> None:
    """
    整体构建流程：
      1. 清空旧的构建目录；
      2. 复制项目中无需构建的静态文件；
      3. 遍历各子插件目录（需存在 info.ini 文件）依次执行打包构建操作。

    参数：
        packet: 包标识
    """
    # 获取当前 Git 最新提交版本信息
    time_tag = git.get_head_time_tag()

    # 删除旧构建结果
    dist_path: str = get_packet_dist_path()
    if os.path.isdir(dist_path):
        shutil.rmtree(dist_path)
    os.makedirs(dist_path, exist_ok=True)

    # 复制不需构建的静态文件（指定忽略的文件列表）
    ignore_files: List[str] = [
        ".7zipignore",
        ".7zipignore-classic",
        ".7zipignore-remake",
        "package.ini",
        "package.ini.zh_TW",
        "README.md",
        "LICENSE",
    ]
    for item in os.listdir("./"):
        if item in ignore_files and os.path.isfile(item):
            shutil.copy2(item, os.path.join("!src-dist", "dist", item))

    # 遍历当前目录中所有子目录，存在 info.ini 的目录认为是子插件
    for item in os.listdir("./"):
        addon_path: str = os.path.join(".", item)
        if os.path.isdir(addon_path) and os.path.exists(
            os.path.join(addon_path, "info.ini")
        ):
            __build_addon(packet, item, time_tag)
            __copy_non_build_files(item)


def __get_version_info(packet: str, diff_ver: Optional[str] = None) -> Dict[str, str]:
    """
    获取版本信息，包括当前版本、最新提交hash及历史版本记录，并从git提交信息中提取release记录。

    此函数现在委托给 plib.git.get_version_info 来实现。

    参数：
        packet: 包标识（用于确定Base.lua路径）
        diff_ver: 指定对比版本（可选）
    返回：
        包含版本信息的字典
    """
    return git.get_version_info(packet, diff_ver)


def __make_changelog(packet: str, packet_path: str, branch: str) -> None:
    """
    生成 CHANGELOG 文件
      根据不同分支（如 remake、classic）筛选内容，并对输出格式做处理。

    参数：
        packet: 包标识
        packet_path: 包所在的路径
        branch: 分支名称（如 remake、classic）
    """
    packet_dist_path = get_packet_dist_path()
    changelog_src: str = os.path.join(packet_path, "CHANGELOG.md")
    with open(changelog_src, "r", encoding="utf8") as input_file:
        input_lines: List[str] = input_file.readlines()

    branch_pattern: re.Pattern = re.compile(r"\*\(.*\b%s\b.*\)\*$" % branch)
    output_lines: List[str] = []

    for index, line in enumerate(input_lines):
        line = line.rstrip()
        if line.endswith(")*"):
            # 如匹配到该分支，则仅截取前面的部分
            match = branch_pattern.search(line)
            if match:
                line = line[: match.start()].rstrip()
            else:
                continue  # 非目标分支行则跳过
        if index < 2:
            continue
        # 避免多余的空行
        if line == "" and output_lines and output_lines[-1].startswith("## "):
            continue
        if (
            line.startswith("## ")
            and output_lines
            and output_lines[-1].startswith("## ")
        ):
            output_lines.pop()
        # 缩进处理
        if line.startswith("* "):
            line = " " + line
        output_lines.append(line + "\n")
    if output_lines and output_lines[-1].startswith("## "):
        output_lines.pop()
    # 去掉二级标题前缀
    for i, line in enumerate(output_lines):
        if line.startswith("## "):
            output_lines[i] = line[3:]
    changelog_target: str = os.path.join(packet_dist_path, f"{packet}_CHANGELOG.txt")
    with open(changelog_target, "w", encoding="gbk") as output_file:
        output_file.writelines(output_lines)


def __7zip(
    packet: str,
    file_name: str,
    base_message: str,
    base_hash: str,
    extra_ignore_file: str,
) -> None:
    """
    使用7z工具进行压缩打包

    参数：
        packet: 包标识
        file_name: 输出压缩包完整路径
        base_message: 上一个版本的提交信息
        base_hash: 上一个版本对应的提交 hash
        extra_ignore_file: 额外忽略项配置文件
    """
    cmd_suffix: str = ""
    if extra_ignore_file:
        cmd_suffix += f" -x@{extra_ignore_file}"
    # 如存在上一个版本，则生成当前版本自上版本以来发生变更的文件列表
    if base_hash != "":

        def pathToModule(path: str) -> str:
            path = (
                path.strip('"') if path.startswith('"') and path.endswith('"') else path
            )
            # 截取对应模块名称（去掉目录前缀及后续路径）
            return re.sub(r'(?:^\!src-dist/data/|["/].*$)', "", path)

        paths: Dict[str, bool] = {
            "package.ini": True,
            "package.ini.*": True,
            f"{packet}_CHANGELOG.txt": True,
        }
        print("")
        print("--------------------------------")
        print("文件变更列表：")
        filelist: List[str] = (
            utils.read_popen_output(f"git diff {base_hash} HEAD --name-status")
            .strip()
            .split("\n")
        )
        for file in filelist:
            lst: List[str] = file.split("\t")
            if not lst:
                continue
            if lst[0] in ["A", "M", "D"]:
                paths[pathToModule(lst[1])] = True
            elif lst[0].startswith("R"):
                paths[pathToModule(lst[1])] = True
                if len(lst) >= 3:
                    paths[pathToModule(lst[2])] = True
            print(file)
        print("")
        print("子插件变更列表：")
        # 将变更文件的路径追加到7z命令参数中
        for path in paths:
            print("/" + path)
            cmd_suffix += f' "{path}"'
        print("")

    print("--------------------------------")
    print("正在压缩打包...")
    # 调用系统命令压缩包
    if os.name == "nt":
        # Windows: 使用7z.exe命令（通过 start /wait 保证依次完成）
        cmd: str = (
            'cd ./!src-dist/dist && start /wait /b ../bin/7z.exe a -t7z "'
            + file_name
            + '" -xr!manifest.dat -xr!manifest.key -xr!publisher.key -x@.7zipignore'
            + cmd_suffix
        )
    else:
        # Linux/macOS: 使用7z命令
        cmd: str = (
            'cd ./!src-dist/dist && 7z a -bb0 -bd -bso0 -t7z "'
            + file_name
            + '" -xr!manifest.dat -xr!manifest.key -xr!publisher.key -x@.7zipignore'
            + cmd_suffix
        )
    os.system(cmd)
    print(f'压缩打包完成："{file_name}"。')
    if base_hash:
        print(f'基于提交信息："{base_message}({base_hash})"。')
    else:
        print("全量打包。")


def __lint(packet: str, packet_path: str, diff_version: Optional[str] = None) -> None:
    """
    代码检查
    """
    # 获取当前版本信息
    version_info: Dict[str, str] = __get_version_info(packet, diff_version)
    utils.assert_exit(
        version_info.get("current") != "",
        "错误：无法获取当前版本信息，请检查 Base.lua 文件！",
    )
    print(f"当前版本：{version_info.get('current')}")
    print(f"当前提交 hash：{version_info.get('current_hash')}")
    print(f"历史最大版本：{version_info.get('max')}")
    print(f"上一版本：{version_info.get('previous')}")
    print(f"上一版本提交信息：{version_info.get('previous_message')}")
    print(f"上一版本提交 hash：{version_info.get('previous_hash')}")

    # 执行代码检查
    # 从上一版本（如果不存在则从最早commit开始）检查 commit message 是否符合规范
    print("\n正在检查提交信息规范...")

    # 获取起始commit hash
    start_hash = version_info.get("previous_hash") or ""
    if not start_hash:
        # 如果没有上一版本，则获取3个月内最老的commit的hash
        start_hash = utils.read_popen_output(
            'git log --since="3 months ago" --format="%H" --reverse | head -n 1'
        ).strip()
        if not start_hash:
            # 如果3个月内没有commit，则获取最新的commit hash
            start_hash = utils.read_popen_output("git rev-parse HEAD").strip()

    # 获取从起始commit到当前的所有commit信息
    commits = (
        utils.read_popen_output(f'git log {start_hash}..HEAD --pretty=format:"%h|%s"')
        .strip()
        .split("\n")
    )

    # 定义conventional commit的正则表达式
    commit_pattern = re.compile(
        r"^(feat|fix|docs|style|refactor|perf|test|chore|build|release)(\([^)]+\))?: .+"
    )

    has_invalid = False
    invalid_commits = []
    for commit in commits:
        if not commit:
            continue
        hash_msg = commit.split("|")
        if len(hash_msg) != 2:
            continue

        commit_hash, message = hash_msg
        # 忽略 merge commits
        if message.startswith("Merge "):
            continue

        if not commit_pattern.match(message):
            invalid_commits.append(f"  - {commit_hash}: {message}")
            has_invalid = True

    if has_invalid:
        print("\n不规范的提交信息：")
        for invalid_commit in invalid_commits:
            print(invalid_commit)
        utils.exit_with_message(
            "\n错误：存在不符合规范的提交信息！\n提交信息必须符合格式：<type>[optional scope]: <description>\n其中type必须是：feat|fix|docs|style|refactor|perf|test|chore|build|release"
        )
    else:
        print("\n提交信息规范检查通过！")


def __update_assert_version(version_info: Dict[str, str]) -> None:
    """
    更新变更子插件中的 AssertVersion 调用到最新版本

    参数：
        version_info: 版本信息字典，包含当前版本和变更的子插件文件夹
    """
    current_version = version_info.get("current", "")
    changed_folders = version_info.get("changed_addon_folders", [])

    if not current_version:
        print("Warning: No current version found, skipping AssertVersion update")
        return

    if not changed_folders:
        print("No changed addon folders found, skipping AssertVersion update")
        return

    print(f"\n正在更新变更子插件的 AssertVersion 调用到版本 {current_version}...")
    print(f"变更的子插件: {', '.join(changed_folders)}")

    try:
        files_updated, total_updates = update_assert_version_for_changed_addons(
            current_version, force_changed=True
        )

        if total_updates > 0:
            print(
                f"AssertVersion 更新完成: 更新了 {files_updated} 个文件，共 {total_updates} 处更新"
            )
        else:
            print("没有需要更新的 AssertVersion 调用")

    except Exception as e:
        print(f"Warning: AssertVersion 更新过程中出现错误: {e}")


def __prepublish(packet: str, packet_path: str, diff_ver: Optional[str] = None) -> None:
    """
    发布前准备工作：
      - 如果当前在master分支，切换至stable分支、rebase主分支变动并重置提交信息；
      - 如果当前在stable分支且存在未提交变更，则提交release信息；
      - 确保工作区干净且当前分支为stable。

    参数：
        packet: 包标识
        packet_path: 包所在路径
        diff_ver: 指定对比版本（可选）
    """
    # 如当前为master分支，则要求切换至stable分支进行发布操作
    if git.get_current_branch() == "master":
        utils.assert_exit(git.is_clean(), "错误：master分支存在未提交的变更！")
        os.system("git checkout stable || git checkout -b stable")
        os.system("git rebase master")
        os.system("git reset master")
        base_lua_path: str = os.path.join(
            packet_path, f"./{packet}_!Base/src/lib/Base.lua"
        )
        os.system(f'code "{base_lua_path}"')
        os.system(f'code "{os.path.join(packet_path, "./CHANGELOG.md")}"')
        utils.exit_with_message("已切换至stable分支，请提交发布信息后再次运行此脚本！")

    # 当前分支为stable且存在修改，则提交release信息
    if git.get_current_branch() == "stable" and not git.is_clean():
        os.system("git reset master")
        version_info: Dict[str, str] = __get_version_info(packet, diff_ver)
        utils.assert_exit(
            version_info.get("max") == ""
            or semver.compare(version_info.get("current"), version_info.get("max"))
            == 1,
            f"错误：当前版本({version_info.get('current')})必须大于历史最大版本({version_info.get('max')})！",
        )
        __update_assert_version(version_info)
        os.system(
            f'git add * && git commit -m "release: {version_info.get("current")}"'
        )

    # 确保工作区干净且当前分支为stable，再继续打包
    utils.assert_exit(git.is_clean(), "错误：请先解决冲突并清理未提交的变更！")
    utils.assert_exit(
        git.get_current_branch() == "stable", "错误：当前分支不是stable！"
    )


def __pack(packet: str, packet_path: str, version_info: Dict[str, str]) -> None:
    """
    打包流程：
      根据是否存在上一个版本的提交hash，
      分别生成差异包和全量包（分别处理 remake 与 classic 分支）。

    参数：
        packet: 包标识
        packet_path: 包所在的目录
        version_info: 各版本信息字典（包含当前、上一个版本相关信息）
    """
    # 获取当前 Git 最新提交版本信息
    time_tag = git.get_head_time_tag()

    # 根据运行环境确定压缩包输出目录
    interface_path = get_interface_path()
    if interface_path is None:
        dist_root = os.path.join(
            os.path.abspath(__file__),
            os.pardir,
            os.pardir,
            os.pardir,
            "!src-dist",
            "dist",
        )
    else:
        dist_root: str = os.path.abspath(os.path.join(get_interface_path(), os.pardir))
        if os.path.isfile(os.path.abspath(os.path.join(dist_root, "gameupdater.exe"))):
            dist_root = os.path.join(packet_path, "!src-dist", "dist")
        else:
            dist_root = os.path.abspath(os.path.join(dist_root, os.pardir, "dist"))

    # 如果存在上一个版本，则生成差异包
    if version_info.get("previous_hash"):
        file_name_fmt: str = os.path.abspath(
            os.path.join(
                dist_root,
                f"{packet}_{time_tag}_v{version_info.get('current')}.%sdiff-{version_info.get('previous_hash')}-{version_info.get('current_hash')}.7z",
            )
        )
        base_message: str = version_info.get("previous_message")
        base_hash: str = version_info.get("previous_hash")
        # 制作 remake 版 changelog 与打包
        __make_changelog(packet, packet_path, "remake")
        __7zip(
            packet,
            file_name_fmt % "remake-",
            base_message,
            base_hash,
            ".7zipignore-remake",
        )
        # 制作 classic 版 changelog 与打包
        __make_changelog(packet, packet_path, "classic")
        __7zip(
            packet,
            file_name_fmt % "classic-",
            base_message,
            base_hash,
            ".7zipignore-classic",
        )

    # 全量包打包流程
    file_name_fmt = os.path.abspath(
        os.path.join(
            dist_root,
            f"{packet}_{time_tag}_v{version_info.get('current')}.%sfull.7z",
        )
    )
    __make_changelog(packet, packet_path, "remake")
    __7zip(packet, file_name_fmt % "remake-", "", "", ".7zipignore-remake")
    __make_changelog(packet, packet_path, "classic")
    __7zip(packet, file_name_fmt % "classic-", "", "", ".7zipignore-classic")


def run(mode: str, diff_ver: Optional[str] = None, is_source: bool = False) -> None:
    """
    脚本入口函数，根据 mode 确定打包或发布流程。

    参数：
        mode: 发布模式，取值 "publish" 或其他（仅打包，不发布）
        diff_ver: 指定对比版本（可选）
        is_source: 是否仅打包源码（目前未使用，可扩展）
    """
    print("> 对比版本: %s" % (diff_ver or "auto"))
    print("> 发布模式: %s" % mode)
    packet: str = get_current_packet_id()
    packet_path: str = get_packet_path()
    version_info: Dict[str, str] = __get_version_info(packet, diff_ver)

    if diff_ver and version_info.get("previous_hash") == "":
        print("错误：指定的对比提交未找到（release: %s）。" % diff_ver)
        exit()

    # 如为发布模式，先执行预发布检查与操作
    if mode == "publish":
        __prepublish(packet, packet_path, diff_ver)

    if mode == "publish" or mode == "ci":
        __lint(packet, packet_path, diff_ver)

    # 执行整体构建打包流程
    __build(packet)

    if mode == "publish" or mode == "ci":
        __pack(packet, packet_path, version_info)

    if mode == "publish":
        os.system("git checkout master")

    print("--------------------------------")
    print("退出...")
    time.sleep(3)
