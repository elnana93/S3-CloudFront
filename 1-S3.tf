#############################
# Private S3 + CloudFront (OAC)

resource "random_id" "site_suffix" {
  byte_length = 4
}

locals {
  site_bucket_name = "resume-site-${random_id.site_suffix.hex}"
}

# --- Private S3 bucket for website content
resource "aws_s3_bucket" "site" {
  bucket        = local.site_bucket_name
  force_destroy = true

 /* lifecycle {
    prevent_destroy = true -- Uncomment to prevent delete of bucket photos 
  }
 */

  tags = {
    Name = local.site_bucket_name
  }
}

# Block ALL public access (this is what makes it truly private)
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Recommended: disable ACLs entirely
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Recommended: encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Optional: versioning (nice for rollbacks)
resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id

  versioning_configuration {
    status = "Enabled"
  }
}



# --- Bucket policy: allow ONLY this CloudFront distribution to read objects
data "aws_iam_policy_document" "site_bucket_policy" {
  statement {
    sid     = "AllowCloudFrontReadOnly"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}


resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.site]
}


output "site_bucket_name" {
  value = aws_s3_bucket.site.bucket
}





# Upload HTML files automatically
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.bucket
  key          = "index.html"
  source       = "${path.module}/site/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/site/index.html")
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.site.bucket
  key          = "error.html"
  source       = "${path.module}/site/error.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/site/error.html")
}


