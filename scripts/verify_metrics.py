#!/usr/bin/env python3
"""
Code Metrics Verification Script

Verifies code metrics compliance:
- Max 500 lines per file (excluding comments/blank lines)
- Max 50 lines per function (excluding comments/blank lines)

Supports Dart and Rust source files.
"""

import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Tuple, Dict


@dataclass
class FileMetrics:
    """Metrics for a single file."""
    path: str
    total_lines: int
    code_lines: int
    comment_lines: int
    blank_lines: int
    violations: List[str]


@dataclass
class FunctionMetrics:
    """Metrics for a single function."""
    name: str
    file_path: str
    line_number: int
    code_lines: int


class MetricsAnalyzer:
    """Analyzes code metrics for Dart and Rust files."""

    MAX_FILE_LINES = 500
    MAX_FUNCTION_LINES = 50

    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.file_metrics: List[FileMetrics] = []
        self.function_metrics: List[FunctionMetrics] = []

    def is_comment_line(self, line: str, lang: str) -> bool:
        """Check if a line is a comment."""
        stripped = line.strip()
        if lang == 'dart':
            return stripped.startswith('//') or stripped.startswith('/*') or stripped.startswith('*')
        elif lang == 'rust':
            return stripped.startswith('//') or stripped.startswith('/*') or stripped.startswith('*')
        return False

    def is_blank_line(self, line: str) -> bool:
        """Check if a line is blank."""
        return len(line.strip()) == 0

    def count_file_lines(self, file_path: Path, lang: str) -> Tuple[int, int, int, int]:
        """
        Count lines in a file.
        Returns: (total_lines, code_lines, comment_lines, blank_lines)
        """
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return (0, 0, 0, 0)

        total_lines = len(lines)
        code_lines = 0
        comment_lines = 0
        blank_lines = 0
        in_block_comment = False

        for line in lines:
            stripped = line.strip()

            # Check for blank lines
            if self.is_blank_line(line):
                blank_lines += 1
                continue

            # Handle block comments
            if '/*' in stripped:
                in_block_comment = True
                comment_lines += 1
                if '*/' in stripped:
                    in_block_comment = False
                continue

            if in_block_comment:
                comment_lines += 1
                if '*/' in stripped:
                    in_block_comment = False
                continue

            # Handle single-line comments
            if self.is_comment_line(line, lang):
                comment_lines += 1
                continue

            # It's a code line
            code_lines += 1

        return (total_lines, code_lines, comment_lines, blank_lines)

    def extract_dart_functions(self, file_path: Path) -> List[FunctionMetrics]:
        """Extract function metrics from a Dart file."""
        functions = []

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return functions

        # Regex to match function/method declarations
        # Matches: void foo(), Future<T> bar(), static int baz(), etc.
        function_pattern = re.compile(
            r'^\s*(?:@\w+\s+)*(?:static\s+)?(?:final\s+)?(?:const\s+)?'
            r'(?:Future<[^>]+>|Stream<[^>]+>|[A-Za-z_]\w*(?:<[^>]+>)?)\s+'
            r'([A-Za-z_]\w*)\s*\([^)]*\)\s*(?:async\s*)?(?:=>|{)'
        )

        i = 0
        while i < len(lines):
            line = lines[i]
            match = function_pattern.search(line)

            if match:
                func_name = match.group(1)
                start_line = i

                # Count lines until the function ends
                brace_count = 0
                is_arrow_function = '=>' in line

                if is_arrow_function:
                    # Arrow function - ends at semicolon
                    func_lines = [lines[i]]
                    i += 1
                    while i < len(lines) and ';' not in lines[i]:
                        func_lines.append(lines[i])
                        i += 1
                    if i < len(lines):
                        func_lines.append(lines[i])
                else:
                    # Regular function with braces
                    func_lines = []
                    brace_count = line.count('{') - line.count('}')
                    func_lines.append(lines[i])
                    i += 1

                    while i < len(lines) and brace_count > 0:
                        func_lines.append(lines[i])
                        brace_count += lines[i].count('{') - lines[i].count('}')
                        i += 1

                # Count code lines (excluding comments and blanks)
                code_lines = 0
                in_block_comment = False

                for func_line in func_lines:
                    stripped = func_line.strip()

                    if self.is_blank_line(func_line):
                        continue

                    if '/*' in stripped:
                        in_block_comment = True
                        if '*/' in stripped:
                            in_block_comment = False
                        continue

                    if in_block_comment:
                        if '*/' in stripped:
                            in_block_comment = False
                        continue

                    if self.is_comment_line(func_line, 'dart'):
                        continue

                    code_lines += 1

                functions.append(FunctionMetrics(
                    name=func_name,
                    file_path=str(file_path),
                    line_number=start_line + 1,
                    code_lines=code_lines
                ))
            else:
                i += 1

        return functions

    def extract_rust_functions(self, file_path: Path) -> List[FunctionMetrics]:
        """Extract function metrics from a Rust file."""
        functions = []

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return functions

        # Regex to match Rust function declarations
        # Matches: fn foo(), pub fn bar(), pub(crate) async fn baz(), etc.
        function_pattern = re.compile(
            r'^\s*(?:#\[[^\]]+\]\s*)*'  # attributes
            r'(?:pub(?:\([^)]+\))?\s+)?'  # visibility
            r'(?:async\s+)?'  # async
            r'(?:unsafe\s+)?'  # unsafe
            r'fn\s+([A-Za-z_]\w*)\s*'  # function name
        )

        i = 0
        while i < len(lines):
            line = lines[i]
            match = function_pattern.search(line)

            if match:
                func_name = match.group(1)
                start_line = i

                # Count lines until the function ends
                brace_count = 0
                func_lines = []

                # Find opening brace
                while i < len(lines) and '{' not in lines[i]:
                    func_lines.append(lines[i])
                    i += 1

                if i >= len(lines):
                    break

                # Count braces
                brace_count = lines[i].count('{') - lines[i].count('}')
                func_lines.append(lines[i])
                i += 1

                while i < len(lines) and brace_count > 0:
                    func_lines.append(lines[i])
                    brace_count += lines[i].count('{') - lines[i].count('}')
                    i += 1

                # Count code lines (excluding comments and blanks)
                code_lines = 0
                in_block_comment = False

                for func_line in func_lines:
                    stripped = func_line.strip()

                    if self.is_blank_line(func_line):
                        continue

                    if '/*' in stripped:
                        in_block_comment = True
                        if '*/' in stripped:
                            in_block_comment = False
                        continue

                    if in_block_comment:
                        if '*/' in stripped:
                            in_block_comment = False
                        continue

                    if self.is_comment_line(func_line, 'rust'):
                        continue

                    code_lines += 1

                functions.append(FunctionMetrics(
                    name=func_name,
                    file_path=str(file_path),
                    line_number=start_line + 1,
                    code_lines=code_lines
                ))
            else:
                i += 1

        return functions

    def analyze_file(self, file_path: Path, lang: str) -> FileMetrics:
        """Analyze a single file."""
        total, code, comments, blanks = self.count_file_lines(file_path, lang)

        violations = []
        if code > self.MAX_FILE_LINES:
            violations.append(f"File exceeds {self.MAX_FILE_LINES} code lines: {code} lines")

        # Extract function metrics
        if lang == 'dart':
            functions = self.extract_dart_functions(file_path)
        elif lang == 'rust':
            functions = self.extract_rust_functions(file_path)
        else:
            functions = []

        # Check function length violations
        for func in functions:
            if func.code_lines > self.MAX_FUNCTION_LINES:
                violations.append(
                    f"Function '{func.name}' at line {func.line_number} exceeds "
                    f"{self.MAX_FUNCTION_LINES} code lines: {func.code_lines} lines"
                )
            self.function_metrics.append(func)

        rel_path = file_path.relative_to(self.project_root)

        return FileMetrics(
            path=str(rel_path),
            total_lines=total,
            code_lines=code,
            comment_lines=comments,
            blank_lines=blanks,
            violations=violations
        )

    def scan_directory(self, directory: Path, pattern: str, lang: str):
        """Scan a directory for files matching a pattern."""
        for file_path in directory.rglob(pattern):
            # Skip generated files and build artifacts
            path_str = str(file_path)
            if any(x in path_str for x in [
                '/build/', '/.dart_tool/', '/target/',
                '.g.dart', '.freezed.dart', 'generated'
            ]):
                continue

            metrics = self.analyze_file(file_path, lang)
            self.file_metrics.append(metrics)

    def generate_report(self) -> str:
        """Generate a compliance report."""
        report_lines = []
        report_lines.append("=" * 80)
        report_lines.append("CODE METRICS COMPLIANCE REPORT")
        report_lines.append("=" * 80)
        report_lines.append("")
        report_lines.append("Standards:")
        report_lines.append(f"  - Max file size: {self.MAX_FILE_LINES} lines (excluding comments/blanks)")
        report_lines.append(f"  - Max function size: {self.MAX_FUNCTION_LINES} lines (excluding comments/blanks)")
        report_lines.append("")

        # Summary statistics
        total_files = len(self.file_metrics)
        total_code_lines = sum(f.code_lines for f in self.file_metrics)
        total_violations = sum(len(f.violations) for f in self.file_metrics)
        files_with_violations = sum(1 for f in self.file_metrics if f.violations)

        report_lines.append("Summary:")
        report_lines.append(f"  - Total files analyzed: {total_files}")
        report_lines.append(f"  - Total code lines: {total_code_lines:,}")
        report_lines.append(f"  - Files with violations: {files_with_violations}")
        report_lines.append(f"  - Total violations: {total_violations}")
        report_lines.append("")

        # Violations by file
        if total_violations > 0:
            report_lines.append("-" * 80)
            report_lines.append("VIOLATIONS")
            report_lines.append("-" * 80)
            report_lines.append("")

            for metrics in sorted(self.file_metrics, key=lambda x: len(x.violations), reverse=True):
                if metrics.violations:
                    report_lines.append(f"File: {metrics.path}")
                    report_lines.append(f"  Code lines: {metrics.code_lines}")
                    for violation in metrics.violations:
                        report_lines.append(f"  ❌ {violation}")
                    report_lines.append("")
        else:
            report_lines.append("✅ All files comply with code metrics standards!")
            report_lines.append("")

        # Top 10 largest files
        report_lines.append("-" * 80)
        report_lines.append("TOP 10 LARGEST FILES (by code lines)")
        report_lines.append("-" * 80)
        report_lines.append("")

        largest_files = sorted(self.file_metrics, key=lambda x: x.code_lines, reverse=True)[:10]
        for i, metrics in enumerate(largest_files, 1):
            status = "✅" if metrics.code_lines <= self.MAX_FILE_LINES else "❌"
            report_lines.append(
                f"{i:2d}. {status} {metrics.path:60s} {metrics.code_lines:4d} lines"
            )
        report_lines.append("")

        # Top 10 largest functions
        report_lines.append("-" * 80)
        report_lines.append("TOP 10 LARGEST FUNCTIONS (by code lines)")
        report_lines.append("-" * 80)
        report_lines.append("")

        largest_functions = sorted(self.function_metrics, key=lambda x: x.code_lines, reverse=True)[:10]
        for i, func in enumerate(largest_functions, 1):
            status = "✅" if func.code_lines <= self.MAX_FUNCTION_LINES else "❌"
            report_lines.append(
                f"{i:2d}. {status} {func.name:30s} {func.code_lines:4d} lines "
                f"({Path(func.file_path).name}:{func.line_number})"
            )
        report_lines.append("")

        report_lines.append("=" * 80)

        return "\n".join(report_lines)


def main():
    """Main entry point."""
    project_root = Path(__file__).parent.parent

    analyzer = MetricsAnalyzer(project_root)

    print("Scanning Dart files...")
    analyzer.scan_directory(project_root / 'lib', '*.dart', 'dart')
    analyzer.scan_directory(project_root / 'test', '*.dart', 'dart')

    print("Scanning Rust files...")
    analyzer.scan_directory(project_root / 'rust/src', '*.rs', 'rust')

    print("\nGenerating report...")
    report = analyzer.generate_report()
    print(report)

    # Save report to file
    report_path = project_root / 'CODE_METRICS_REPORT.md'
    with open(report_path, 'w') as f:
        f.write(report)

    print(f"\nReport saved to: {report_path}")

    # Exit with error code if there are violations
    total_violations = sum(len(f.violations) for f in analyzer.file_metrics)
    if total_violations > 0:
        print(f"\n❌ Found {total_violations} violations")
        return 1
    else:
        print("\n✅ All code complies with metrics standards")
        return 0


if __name__ == '__main__':
    sys.exit(main())
