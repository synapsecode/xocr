#!/usr/bin/env python3

from apple_ocr.ocr import OCR
from PIL import Image
import argparse

def get_lines(elements):
    line_threshold = 0.015
    lines = []
    current_line = []
    prev_y = None

    for word, x, y, w in elements:
        if prev_y is None or abs(y - prev_y) < line_threshold:
            current_line.append((word, x, w))
        else:
            lines.append(current_line)
            current_line = [(word, x, w)]
        prev_y = y

    if current_line:
        lines.append(current_line)
    return lines

def correct_lines(lines, min_x):
    GRANULARITY = 0.02
    INDENT_LEVEL = 4
    WORD_SPACING = 0.01
    final_lines = []
    for line in lines:
        line = sorted(line, key=lambda e: e[1])
        first_x = line[0][1]
        relative_x = max(0, first_x - min_x)
        indent_level = int(relative_x / GRANULARITY)
        indent = " " * (indent_level * INDENT_LEVEL)

        line_str = indent
        last_end = line[0][1]

        for i, (word, x, w) in enumerate(line):
            if i == 0:
                line_str += word
            else:
                gap = x - last_end
                num_spaces = max(1, int(gap / WORD_SPACING))
                line_str += " " * num_spaces + word
            last_end = x + w

        final_lines.append(line_str)
    return final_lines

def extract_code(code_source):
    image = Image.open(code_source)
    ocr_instance = OCR(image=image)
    ocr_result = ocr_instance.recognize()

    words = ocr_result['Content']
    xs = ocr_result['x']
    ys = ocr_result['y']
    widths = ocr_result['Length']

    elements = list(zip(words, xs, ys, widths))
    elements.sort(key=lambda e: -e[2])  # sort by y-values

    lines = get_lines(elements)
    min_x = min(e[1] for e in elements)
    corrected_lines = correct_lines(lines, min_x)

    return "\n".join(corrected_lines)

def main():
    parser = argparse.ArgumentParser(description="Accept a file path as input.")
    parser.add_argument("file_path", type=str, help="Path to the input file")
    args = parser.parse_args()

    code = extract_code(args.file_path)
    print(code)

if __name__ == '__main__':
    main()