# -*- coding: utf-8 -*-
from __future__ import annotations

import json
import math
import sys
from pathlib import Path


PAGE_WIDTH = 595.0
PAGE_HEIGHT = 842.0
MARGIN_LEFT = 32.0
MARGIN_RIGHT = 32.0
MARGIN_TOP = 42.0
MARGIN_BOTTOM = 34.0
ROW_HEIGHT = 18.0
HEADER_HEIGHT = 22.0

COLUMNS = [
    ("Zeit", 48.0),
    ("Nutzer", 92.0),
    ("Rolle", 58.0),
    ("Nachricht", 165.0),
    ("Regel", 66.0),
    ("Aktion", 63.0),
    ("Begründung", 91.0),
]


def pdf_escape(text: str) -> str:
    raw = str(text or "")
    raw = raw.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
    return raw.replace("\r", " ").replace("\n", " ")


def latin1_safe(text: str) -> str:
    return str(text or "").encode("latin-1", "replace").decode("latin-1")


def fit_text(text: str, width: float, font_size: float = 7.2) -> str:
    safe = latin1_safe(text)
    max_chars = max(1, int(width / (font_size * 0.50)))
    if len(safe) <= max_chars:
        return safe
    if max_chars <= 3:
        return safe[:max_chars]
    return safe[: max_chars - 3] + "..."


def text_command(x: float, y: float, text: str, size: float = 7.2, bold: bool = False) -> str:
    font = "/F2" if bold else "/F1"
    return f"BT {font} {size:.1f} Tf {x:.1f} {y:.1f} Td ({pdf_escape(text)}) Tj ET\n"


def line_command(x1: float, y1: float, x2: float, y2: float, width: float = 0.4) -> str:
    return f"{width:.2f} w {x1:.1f} {y1:.1f} m {x2:.1f} {y2:.1f} l S\n"


def rect_fill(x: float, y: float, width: float, height: float, gray: float) -> str:
    return f"{gray:.3f} g {x:.1f} {y:.1f} {width:.1f} {height:.1f} re f 0 g\n"


def make_page(rows: list[dict]) -> bytes:
    content = []

    title_y = PAGE_HEIGHT - MARGIN_TOP
    content.append(text_command(MARGIN_LEFT, title_y, "Chatwächter-Protokoll", 16.0, True))

    table_top = title_y - 28.0
    total_width = sum(width for _, width in COLUMNS)

    content.append(rect_fill(MARGIN_LEFT, table_top - HEADER_HEIGHT, total_width, HEADER_HEIGHT, 0.13))

    x = MARGIN_LEFT
    for header, width in COLUMNS:
        content.append(text_command(x + 3.0, table_top - 15.0, header, 7.2, True))
        x += width

    y = table_top - HEADER_HEIGHT
    content.append(line_command(MARGIN_LEFT, y, MARGIN_LEFT + total_width, y, 0.6))

    for row_index, row in enumerate(rows):
        next_y = y - ROW_HEIGHT

        if row_index % 2 == 1:
            content.append(rect_fill(MARGIN_LEFT, next_y, total_width, ROW_HEIGHT, 0.95))

        values = [
            row.get("Zeit", ""),
            row.get("Nutzer", ""),
            row.get("Rolle", ""),
            row.get("Nachricht", ""),
            row.get("Regel", ""),
            row.get("Aktion", ""),
            row.get("Begründung", ""),
        ]

        x = MARGIN_LEFT
        for (_, width), value in zip(COLUMNS, values):
            fitted = fit_text(value, width - 6.0)
            content.append(text_command(x + 3.0, next_y + 5.5, fitted, 7.2))
            x += width

        content.append(line_command(MARGIN_LEFT, next_y, MARGIN_LEFT + total_width, next_y, 0.25))
        y = next_y

    x = MARGIN_LEFT
    content.append(line_command(x, table_top, x, y, 0.45))
    for _, width in COLUMNS:
        x += width
        content.append(line_command(x, table_top, x, y, 0.45))

    content.append(line_command(MARGIN_LEFT, table_top, MARGIN_LEFT + total_width, table_top, 0.6))
    return "".join(content).encode("latin-1", "replace")


def build_pdf(rows: list[dict], output_path: Path) -> None:
    available_height = PAGE_HEIGHT - MARGIN_TOP - MARGIN_BOTTOM - 72.0
    rows_per_page = max(1, int(available_height // ROW_HEIGHT))

    pages = [
        rows[index : index + rows_per_page]
        for index in range(0, len(rows), rows_per_page)
    ] or [[]]

    objects: list[bytes] = []

    def add_object(data: bytes) -> int:
        objects.append(data)
        return len(objects)

    font_regular = add_object(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    font_bold = add_object(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>")

    page_object_ids = []
    page_data = []

    for page_rows in pages:
        stream = make_page(page_rows)
        content_id = add_object(
            f"<< /Length {len(stream)} >>\nstream\n".encode("ascii")
            + stream
            + b"\nendstream"
        )
        page_data.append(content_id)
        page_object_ids.append(None)

    pages_id_placeholder = len(objects) + len(pages) + 1

    for index, content_id in enumerate(page_data):
        page_id = add_object(
            (
                f"<< /Type /Page /Parent {pages_id_placeholder} 0 R "
                f"/MediaBox [0 0 {PAGE_WIDTH:.0f} {PAGE_HEIGHT:.0f}] "
                f"/Resources << /Font << /F1 {font_regular} 0 R /F2 {font_bold} 0 R >> >> "
                f"/Contents {content_id} 0 R >>"
            ).encode("ascii")
        )
        page_object_ids[index] = page_id

    kids = " ".join(f"{page_id} 0 R" for page_id in page_object_ids)
    pages_id = add_object(
        f"<< /Type /Pages /Kids [{kids}] /Count {len(page_object_ids)} >>".encode("ascii")
    )

    if pages_id != pages_id_placeholder:
        raise RuntimeError("Interner PDF-Seitenverweis stimmt nicht.")

    catalog_id = add_object(f"<< /Type /Catalog /Pages {pages_id} 0 R >>".encode("ascii"))

    output = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]

    for object_id, data in enumerate(objects, start=1):
        offsets.append(len(output))
        output.extend(f"{object_id} 0 obj\n".encode("ascii"))
        output.extend(data)
        output.extend(b"\nendobj\n")

    xref_offset = len(output)
    output.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    output.extend(b"0000000000 65535 f \n")

    for offset in offsets[1:]:
        output.extend(f"{offset:010d} 00000 n \n".encode("ascii"))

    output.extend(
        (
            f"trailer\n<< /Size {len(objects) + 1} /Root {catalog_id} 0 R >>\n"
            f"startxref\n{xref_offset}\n%%EOF\n"
        ).encode("ascii")
    )

    output_path.write_bytes(output)


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: export_chat_pdf.py INPUT_JSON OUTPUT_PDF", file=sys.stderr)
        return 2

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    rows = json.loads(input_path.read_text(encoding="utf-8"))
    build_pdf(rows, output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
