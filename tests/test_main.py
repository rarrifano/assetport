from unittest.mock import MagicMock, patch

from app.main import human_readable_size, is_s3_configured, upload_to_s3


# ---------------------------------------------------------------------------
# human_readable_size
# ---------------------------------------------------------------------------
def test_human_readable_size_bytes() -> None:
    assert human_readable_size(0) == "0 B"
    assert human_readable_size(512) == "512.0 B"


def test_human_readable_size_kilobytes() -> None:
    assert human_readable_size(1024) == "1.0 KB"
    assert human_readable_size(2048) == "2.0 KB"


def test_human_readable_size_megabytes() -> None:
    assert human_readable_size(1024 * 1024) == "1.0 MB"


def test_human_readable_size_gigabytes() -> None:
    assert human_readable_size(1024**3) == "1.0 GB"


# ---------------------------------------------------------------------------
# is_s3_configured
# ---------------------------------------------------------------------------
def test_s3_not_configured_when_env_missing(monkeypatch: MagicMock) -> None:
    monkeypatch.setattr("app.main.AWS_BUCKET_NAME", "")
    monkeypatch.setattr("app.main.CLOUDFRONT_DOMAIN", "")
    assert is_s3_configured() is False


def test_s3_configured_when_env_present(monkeypatch: MagicMock) -> None:
    monkeypatch.setattr("app.main.AWS_BUCKET_NAME", "my-bucket")
    monkeypatch.setattr("app.main.CLOUDFRONT_DOMAIN", "https://abc.cloudfront.net")
    assert is_s3_configured() is True


# ---------------------------------------------------------------------------
# upload_to_s3
# ---------------------------------------------------------------------------
def test_upload_to_s3_returns_public_url(monkeypatch: MagicMock) -> None:
    monkeypatch.setattr("app.main.AWS_BUCKET_NAME", "test-bucket")
    monkeypatch.setattr("app.main.CLOUDFRONT_DOMAIN", "https://cdn.example.com")
    monkeypatch.setattr("app.main.AWS_REGION", "us-east-1")

    mock_file = MagicMock()
    mock_file.name = "banner.png"
    mock_file.type = "image/png"

    with patch("app.main.boto3.client") as mock_boto:
        mock_s3 = MagicMock()
        mock_boto.return_value = mock_s3
        result = upload_to_s3(mock_file)

    assert result == "https://cdn.example.com/banner.png"
    mock_s3.upload_fileobj.assert_called_once()


def test_upload_to_s3_returns_none_on_error(monkeypatch: MagicMock) -> None:
    from botocore.exceptions import ClientError

    monkeypatch.setattr("app.main.AWS_BUCKET_NAME", "test-bucket")
    monkeypatch.setattr("app.main.CLOUDFRONT_DOMAIN", "https://cdn.example.com")
    monkeypatch.setattr("app.main.AWS_REGION", "us-east-1")

    mock_file = MagicMock()
    mock_file.name = "banner.png"
    mock_file.type = "image/png"

    with patch("app.main.boto3.client") as mock_boto:
        mock_s3 = MagicMock()
        mock_s3.upload_fileobj.side_effect = ClientError(
            {"Error": {"Code": "NoSuchBucket", "Message": "bucket not found"}},
            "PutObject",
        )
        mock_boto.return_value = mock_s3
        with patch("app.main.st.error"):
            result = upload_to_s3(mock_file)

    assert result is None
