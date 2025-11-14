#!/usr/bin/env python3
"""
Code Metrics Checker - Verifies compliance with code quality KPIs
- Max 500 lines/file (excluding comments/blanks)
- Max 50 lines/function (excluding comments/blanks)
"""

import os
import re
from pathlib import Path
from typing import List, Tuple, Dict
import json

# Configuration
MAX_FILE_LINES = 500
MAX_FUNCTION_LINES = 50
DART_EXTENSIONS = ['.dart']
RUST_EXTENSIONS = ['.rs']
EXCLUDE_DIRS = ['build', 'target', '.dart_tool', 'generated', 'ios', 'android', 'windows', 'linux', 'macos', 'web']
EXCLUDE_FILES = ['_test.dart', '.g.dart', '.freezed.dart']

class CodeMetrics:
    def __init__(self):
        self.violations = []
        self.stats = {
            'total_files': 0,
            'total_functions': 0,
            'oversized_files': 0,
            'oversized_functions': 0,
            'max_file_size': 0,
            'max_function_size': 0
        }

    def count_code_lines(self, lines: List[str]) -> int:
        """Count lines excluding comments and blanks"""
        count = 0
        in_block_comment = False

        for line in lines:
            stripped = line.strip()

            # Skip blank lines
            if not stripped:
                continue

            # Handle Rust/Dart block comments
            if '/*' in stripped:
                in_block_comment = True
            if '*/' in stripped:
                in_block_comment = False
                continue
            if in_block_comment:
                continue

            # Skip single-line comments
            if stripped.startswith('//') or stripped.startswith('#'):
                continue

            count += 1

        return count

    def check_file_size(self, file_path: Path) -> bool:
        """Check if file exceeds max lines"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()

            code_lines = self.count_code_lines(lines)
            self.stats['total_files'] += 1
            self.stats['max_file_size'] = max(self.stats['max_file_size'], code_lines)

            if code_lines > MAX_FILE_LINES:
                self.violations.append({
                    'type': 'file_size',
                    'file': str(file_path),
                    'lines': code_lines,
                    'limit': MAX_FILE_LINES
                })
                self.stats['oversized_files'] += 1
                return False

            return True
        except Exception as e:
            print(f"Error checking {file_path}: {e}")
            return True

    def find_dart_functions(self, lines: List[str]) -> List[Tuple[str, int, int]]:
        """Find Dart functions and their line ranges"""
        functions = []
        current_function = None
        brace_count = 0

        for i, line in enumerate(lines):
            stripped = line.strip()

            # Match function declarations
            if re.match(r'^\s*(Future<.*?>|Stream<.*?>|void|bool|int|double|String|[\w<>]+)\s+\w+\s*\(', line):
                if '{' in line and current_function is None:
                    current_function = (stripped, i + 1, 0)
                    brace_count = line.count('{') - line.count('}')

            # Track braces
            if current_function:
                brace_count += line.count('{') - line.count('}')
                if brace_count == 0:
                    functions.append((current_function[0], current_function[1], i + 1))
                    current_function = None

        return functions

    def find_rust_functions(self, lines: List[str]) -> List[Tuple[str, int, int]]:
        """Find Rust functions and their line ranges"""
        functions = []
        current_function = None
        brace_count = 0

        for i, line in enumerate(lines):
            stripped = line.strip()

            # Match function declarations (pub fn, fn, async fn, pub async fn)
            if re.match(r'^\s*(pub\s+)?(async\s+)?fn\s+\w+', line):
                if '{' in line and current_function is None:
                    current_function = (stripped, i + 1, 0)
                    brace_count = line.count('{') - line.count('}')

            # Track braces
            if current_function:
                brace_count += line.count('{') - line.count('}')
                if brace_count == 0:
                    functions.append((current_function[0], current_function[1], i + 1))
                    current_function = None

        return functions

    def check_function_sizes(self, file_path: Path) -> bool:
        """Check if any function exceeds max lines"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()

            # Determine language and find functions
            if file_path.suffix in DART_EXTENSIONS:
                functions = self.find_dart_functions(lines)
            elif file_path.suffix in RUST_EXTENSIONS:
                functions = self.find_rust_functions(lines)
            else:
                return True

            all_pass = True
            for func_name, start, end in functions:
                function_lines = lines[start-1:end]
                code_lines = self.count_code_lines(function_lines)

                self.stats['total_functions'] += 1
                self.stats['max_function_size'] = max(self.stats['max_function_size'], code_lines)

                if code_lines > MAX_FUNCTION_LINES:
                    self.violations.append({
                        'type': 'function_size',
                        'file': str(file_path),
                        'function': func_name[:60],
                        'lines': code_lines,
                        'limit': MAX_FUNCTION_LINES,
                        'location': f'{file_path}:{start}'
                    })
                    self.stats['oversized_functions'] += 1
                    all_pass = False

            return all_pass
        except Exception as e:
            print(f"Error checking functions in {file_path}: {e}")
            return True

    def should_skip(self, path: Path) -> bool:
        """Check if path should be skipped"""
        path_str = str(path)

        # Skip excluded directories
        for exclude_dir in EXCLUDE_DIRS:
            if f'/{exclude_dir}/' in path_str or path_str.startswith(exclude_dir):
                return True

        # Skip excluded file patterns
        for exclude_file in EXCLUDE_FILES:
            if exclude_file in path.name:
                return True

        return False

    def scan_directory(self, root_dir: Path):
        """Scan directory for code files"""
        extensions = DART_EXTENSIONS + RUST_EXTENSIONS

        for ext in extensions:
            for file_path in root_dir.rglob(f'*{ext}'):
                if self.should_skip(file_path):
                    continue

                self.check_file_size(file_path)
                self.check_function_sizes(file_path)

    def generate_report(self) -> Dict:
        """Generate metrics report"""
        return {
            'compliance': len(self.violations) == 0,
            'statistics': self.stats,
            'violations': self.violations,
            'summary': {
                'total_violations': len(self.violations),
                'file_violations': self.stats['oversized_files'],
                'function_violations': self.stats['oversized_functions']
            }
        }


def main():
    project_root = Path(__file__).parent.parent
    metrics = CodeMetrics()

    print("🔍 Scanning codebase for code metrics compliance...")
    print(f"   Max file size: {MAX_FILE_LINES} lines")
    print(f"   Max function size: {MAX_FUNCTION_LINES} lines")
    print()

    metrics.scan_directory(project_root)

    report = metrics.generate_report()

    # Print summary
    print("📊 Code Metrics Summary:")
    print(f"   Total files scanned: {report['statistics']['total_files']}")
    print(f"   Total functions scanned: {report['statistics']['total_functions']}")
    print(f"   Max file size: {report['statistics']['max_file_size']} lines")
    print(f"   Max function size: {report['statistics']['max_function_size']} lines")
    print()

    if report['compliance']:
        print("✅ All code metrics compliant!")
        return 0
    else:
        print(f"❌ Found {report['summary']['total_violations']} violations:")
        print(f"   - Oversized files: {report['summary']['file_violations']}")
        print(f"   - Oversized functions: {report['summary']['function_violations']}")
        print()

        # Group violations by type
        file_violations = [v for v in report['violations'] if v['type'] == 'file_size']
        function_violations = [v for v in report['violations'] if v['type'] == 'function_size']

        if file_violations:
            print("📄 Oversized Files:")
            for v in file_violations:
                print(f"   - {v['file']}: {v['lines']} lines (limit: {v['limit']})")
            print()

        if function_violations:
            print("🔧 Oversized Functions:")
            for v in function_violations[:20]:  # Show first 20
                print(f"   - {v['location']}")
                print(f"     {v['function']}")
                print(f"     {v['lines']} lines (limit: {v['limit']})")

            if len(function_violations) > 20:
                print(f"   ... and {len(function_violations) - 20} more")

        return 1


if __name__ == '__main__':
    exit(main())
