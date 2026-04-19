import math
import os
from typing import Any

import boto3
import streamlit as st
from botocore.exceptions import BotoCoreError, ClientError

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
AWS_BUCKET_NAME = os.environ.get("AWS_BUCKET_NAME", "")
CLOUDFRONT_DOMAIN = os.environ.get("CLOUDFRONT_DOMAIN", "").rstrip("/")

ACCEPTED_TYPES = [
    "png",
    "jpg",
    "jpeg",
    "gif",
    "webp",  # images
    "pdf",
    "docx",
    "txt",
    "csv",  # documents
    "html",
    "zip",  # mail assets
]

IMAGE_TYPES = {"png", "jpg", "jpeg", "gif", "webp"}

FILE_ICONS: dict[str, str] = {
    "pdf": "📄",
    "docx": "📝",
    "txt": "📃",
    "csv": "📊",
    "html": "🌐",
    "zip": "🗜️",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def human_readable_size(size_bytes: int) -> str:
    if size_bytes == 0:
        return "0 B"
    units = ("B", "KB", "MB", "GB")
    exp = min(int(math.log(size_bytes, 1024)), len(units) - 1)
    value = size_bytes / (1024**exp)
    return f"{value:.1f} {units[exp]}"


def is_s3_configured() -> bool:
    return bool(AWS_BUCKET_NAME and CLOUDFRONT_DOMAIN)


def upload_to_s3(file: Any) -> str | None:
    """Upload file to S3 with public-read ACL. Returns the public CloudFront URL."""
    try:
        s3 = boto3.client("s3", region_name=AWS_REGION)
        ext = file.name.rsplit(".", 1)[-1].lower()
        content_type = file.type or f"application/{ext}"

        s3.upload_fileobj(
            file,
            AWS_BUCKET_NAME,
            file.name,
            ExtraArgs={
                "ACL": "public-read",
                "ContentType": content_type,
            },
        )
        return f"{CLOUDFRONT_DOMAIN}/{file.name}"
    except (BotoCoreError, ClientError) as exc:
        st.error(f"S3 upload failed for **{file.name}**: `{exc}`")
        return None


# ---------------------------------------------------------------------------
# UI components
# ---------------------------------------------------------------------------
def render_header() -> None:
    wrap = (
        "background:linear-gradient(90deg,#1e2d5a 0%,#2e4080 100%);"
        "padding:1.2rem 2rem;border-radius:8px;margin-bottom:1rem;"
        "display:flex;align-items:center;gap:1rem;"
    )
    h1 = "color:#fff;margin:0;font-size:1.8rem;font-weight:700;letter-spacing:1px;"
    sub = "color:#a0aec0;margin:0;font-size:0.9rem;"
    st.markdown(
        f"""
        <div style="{wrap}">
            <span style="font-size:2rem;">📦</span>
            <div>
                <h1 style="{h1}">Assetport</h1>
                <p style="{sub}">Mail Asset Upload Portal</p>
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )
    st.divider()


def render_file_card(file: Any, public_url: str | None) -> None:
    ext = file.name.rsplit(".", 1)[-1].lower()
    is_image = ext in IMAGE_TYPES

    with st.container(border=True):
        if is_image:
            col_preview, col_info = st.columns([1, 2])
            with col_preview:
                st.image(file, use_container_width=True)
        else:
            col_info = st.container()

        with col_info:
            icon = FILE_ICONS.get(ext, "📎")
            st.markdown(f"### {icon} {file.name}")
            st.caption(f"**Type:** `{file.type or ext.upper()}`")
            st.caption(f"**Size:** {human_readable_size(file.size)}")

            if public_url:
                st.text_input(
                    "Public URL",
                    value=public_url,
                    key=f"url_{file.name}",
                    help="Copy this URL to use in your email campaigns",
                )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    st.set_page_config(
        page_title="Assetport",
        page_icon="📦",
        layout="wide",
    )

    render_header()

    st.subheader("📦 Assetport — Mail Asset Upload")
    st.write("Drag and drop your mail assets below, or click to browse.")

    if not is_s3_configured():
        st.warning(
            "⚠️ S3 is not configured. Files will be previewed but **not persisted**. "
            "Set `AWS_BUCKET_NAME` and `CLOUDFRONT_DOMAIN` environment variables.",
            icon="⚠️",
        )

    uploaded_files = st.file_uploader(
        label="Drop files here",
        type=ACCEPTED_TYPES,
        accept_multiple_files=True,
        label_visibility="collapsed",
    )

    if not uploaded_files:
        st.info(
            "Accepted formats: **Images** (PNG, JPG, GIF, WEBP) · "
            "**Documents** (PDF, DOCX, TXT, CSV) · "
            "**Mail assets** (HTML, ZIP)",
            icon="ℹ️",
        )
        return

    # Upload to S3 and collect results
    results: dict[str, str | None] = {}
    if is_s3_configured():
        with st.spinner("Uploading to S3…"):
            for file in uploaded_files:
                file.seek(0)
                results[file.name] = upload_to_s3(file)
                file.seek(0)  # reset so image preview works

        uploaded_count = sum(1 for v in results.values() if v)
        failed_count = len(results) - uploaded_count

        if uploaded_count:
            st.success(
                f"{uploaded_count} file(s) uploaded to S3 successfully!", icon="✅"
            )
        if failed_count:
            st.error(f"{failed_count} file(s) failed to upload.", icon="❌")
    else:
        for file in uploaded_files:
            results[file.name] = None
        st.success(f"{len(uploaded_files)} file(s) ready (preview only).", icon="✅")

    st.divider()

    cols = st.columns(3)
    for idx, file in enumerate(uploaded_files):
        with cols[idx % 3]:
            render_file_card(file, results.get(file.name))


if __name__ == "__main__":
    main()
