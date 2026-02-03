

# This block MUST exist for the distribution to reference it
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "site-oac-${random_id.site_suffix.hex}"
  description                       = "OAC for private S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


# This tells Terraform to go find the ID for the standard "CachingOptimized" policy
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}


resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  # 1. PRIMARY ORIGIN
  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "primaryS3"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  # 2. BACKUP ORIGIN (Your site2 bucket)
  origin {
    domain_name              = aws_s3_bucket.site2.bucket_regional_domain_name
    origin_id                = "backupS3"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  # 3. ORIGIN GROUP (The "Failover" Logic)
  origin_group {
    origin_id = "failoverGroup"

    failover_criteria {
      # Switch to backup if primary returns any of these errors
      status_codes = [403, 404, 500, 502, 503, 504]
    }

    member {
      origin_id = "primaryS3"
    }

    member {
      origin_id = "backupS3"
    }
  }

  default_cache_behavior {
    # IMPORTANT: Point this to the GROUP, not just one bucket
    target_origin_id       = "failoverGroup"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # Custom error responses remain the same
  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/error.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/error.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}


output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.site.domain_name
}


output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.site.id
}





