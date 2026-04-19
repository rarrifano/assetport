# ---------------------------------------------------------------------------
# CloudFront — CDN in front of S3 for public asset URLs
# ---------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "assets" {
  name                              = "assetport-oac"
  description                       = "OAC for Assetport S3 assets bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "assets" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Assetport mail assets CDN"
  default_root_object = ""
  price_class         = "PriceClass_100" # US + Europe only — cheapest

  origin {
    domain_name              = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id                = "assetport-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.assets.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "assetport-s3"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # Optional custom domain
  dynamic "aliases" {
    for_each = var.cloudfront_domain_alias != "" ? [var.cloudfront_domain_alias] : []
    content {
      # terraform forces this inside the block — using local variable
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.cloudfront_domain_alias == ""
    # Uncomment when using a custom domain:
    # acm_certificate_arn      = aws_acm_certificate_validation.assets[0].certificate_arn
    # ssl_support_method       = "sni-only"
    # minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "assetport-cdn"
  }
}

# Allow CloudFront to read from the private S3 bucket
data "aws_iam_policy_document" "cloudfront_s3_policy" {
  statement {
    sid    = "AllowCloudFrontOAC"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.assets.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.assets.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudfront_read" {
  bucket = aws_s3_bucket.assets.id
  policy = data.aws_iam_policy_document.cloudfront_s3_policy.json

  depends_on = [aws_s3_bucket_public_access_block.assets]
}
