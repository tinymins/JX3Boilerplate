#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
更新Lua文件中的AssertVersion调用版本号
"""

import os
import re
import sys
from plib.semver import Semver, satisfies as semver_satisfies


def should_update_version_constraint(constraint, new_version):
    """
    判断版本约束是否需要更新
    返回 (是否需要更新, 新的约束字符串)
    """
    constraint = constraint.strip().strip("'\"")

    try:
        # 使用我们的 semver 模块检查新版本是否满足约束
        satisfies = semver_satisfies(new_version, constraint)

        if not satisfies:
            # 需要更新约束，统一使用 ^ 格式
            new_constraint = f"^{new_version}"
            return True, new_constraint

        return False, constraint

    except Exception as e:
        print(f"Warning: Cannot process version constraint '{constraint}': {e}")
        return False, constraint


def find_lua_files(directory):
    """
    递归查找所有Lua文件
    """
    lua_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".lua"):
                lua_files.append(os.path.join(root, file))
    return lua_files


def update_assert_version_in_file(file_path, new_version):
    """
    更新单个文件中的AssertVersion调用
    返回 (是否有更新, 更新的数量)
    """
    # 尝试不同的编码读取文件
    content = None
    encoding_used = None

    for encoding in ["gbk", "utf-8", "utf-8-sig"]:
        try:
            with open(file_path, "r", encoding=encoding) as f:
                content = f.read()
                encoding_used = encoding
                break
        except UnicodeDecodeError:
            continue

    if content is None:
        print(f"Warning: Cannot read file {file_path} due to encoding issues")
        return False, 0

    # 匹配 AssertVersion 调用的正则表达式
    # 匹配类似：X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^27.0.0')
    pattern = r'(\w+\.AssertVersion\s*\([^,]+,\s*[^,]+,\s*["\'])([^"\']+)(["\'])'

    updated_content = content
    update_count = 0

    def replace_version(match):
        nonlocal update_count
        prefix = match.group(1)
        version_constraint = match.group(2)
        suffix = match.group(3)

        should_update, new_constraint = should_update_version_constraint(
            version_constraint, new_version
        )

        if should_update:
            update_count += 1
            print(f"  {file_path}: {version_constraint} -> {new_constraint}")
            return f"{prefix}{new_constraint}{suffix}"

        return match.group(0)

    updated_content = re.sub(pattern, replace_version, updated_content)

    if update_count > 0:
        try:
            # 使用相同的编码写回文件
            with open(file_path, "w", encoding=encoding_used) as f:
                f.write(updated_content)
            return True, update_count
        except Exception as e:
            print(f"Error writing file {file_path}: {e}")
            return False, 0

    return False, 0


def main():
    """
    主函数
    """
    if len(sys.argv) != 2:
        print("Usage: python update_semver.py <new_version>")
        sys.exit(1)

    new_version = sys.argv[1]

    # 验证新版本格式
    try:
        Semver(new_version)
    except Exception:
        print(f"Error: Invalid version format: {new_version}")
        sys.exit(1)

    # 获取当前目录
    current_dir = os.getcwd()
    print(f"Scanning Lua files in: {current_dir}")
    print(f"Target version: {new_version}")
    print()

    # 查找所有Lua文件
    lua_files = find_lua_files(current_dir)
    print(f"Found {len(lua_files)} Lua files")

    total_files_updated = 0
    total_updates = 0

    # 处理每个文件
    for file_path in lua_files:
        file_updated, update_count = update_assert_version_in_file(
            file_path, new_version
        )
        if file_updated:
            total_files_updated += 1
            total_updates += update_count

    print()
    print("Summary:")
    print(f"  Files updated: {total_files_updated}")
    print(f"  Total updates: {total_updates}")

    if total_updates > 0:
        print(
            f"Successfully updated {total_updates} AssertVersion calls in {total_files_updated} files"
        )
    else:
        print("No AssertVersion calls needed to be updated")


if __name__ == "__main__":
    main()
