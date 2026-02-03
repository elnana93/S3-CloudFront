
# 1. Configure the AWS provider for the replica region
provider "aws" {
  alias  = "replica"
  region = "us-west-1"
} 

# 2. Define your bucket names
locals {
  site2_bucket_name = "resume-site2-${random_id.site_suffix.hex}"
}

# 3. Create the Replica Bucket
resource "aws_s3_bucket" "site2" {
  provider      = aws.replica # Matches your provider alias
  bucket        = local.site2_bucket_name
  force_destroy = true

  tags = {
    # FIXED: Now matches the local name defined above
    Name = local.site2_bucket_name 
  }
}

# 4. Enable Versioning (MANDATORY for replication)
resource "aws_s3_bucket_versioning" "site2" {
  provider = aws.replica
  bucket   = aws_s3_bucket.site2.id
  versioning_configuration {
    status = "Enabled"
  }
}


# --- 1. The IAM Role (The Moving Truck) ---
resource "aws_iam_role" "replication" {
  name = "s3-replication-role-${random_id.site_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
    }]
  })
}

# --- 2. The Permission Policy (The Map) ---
resource "aws_iam_policy" "replication" {
  name = "s3-replication-policy-${random_id.site_suffix.hex}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Permissions for the Source Bucket
        Action   = [
          "s3:GetReplicationConfiguration", 
          "s3:ListBucket",
          "s3:GetBucketVersioning" # <--- ADDED: S3 needs to verify versioning is on
        ]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.site.arn]
      },
      {
        # Permissions to grab the actual files (Versions) from Source
        Action   = [
          "s3:GetObjectVersionForReplication", 
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging" # <--- RECOMMENDED: Ensures tags move too
        ]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.site.arn}/*"]
      },
      {
        # Permissions to drop the files into the Destination
        Action   = [
          "s3:ReplicateObject", 
          "s3:ReplicateDelete",
          "s3:PutObject" # <--- ADDED: This is the actual permission to write files
        ]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.site2.arn}/*"]
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

# --- 3. The Replication Rule (The Command) ---
resource "aws_s3_bucket_replication_configuration" "replication" {
  # We MUST wait for versioning to be active on both before this runs
  depends_on = [aws_s3_bucket_versioning.site, aws_s3_bucket_versioning.site2]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.site.id # Source bucket ID

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.site2.arn # Destination bucket ARN
      storage_class = "STANDARD"
    }

    # Replicate everything (index.html, resume.pdf, etc.)
    filter {
      prefix = ""
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
}