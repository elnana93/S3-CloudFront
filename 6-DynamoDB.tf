

resource "aws_dynamodb_table" "visitor_counter" {
  name           = "visitor-counter"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# This puts the initial starting value of 0 into your table
resource "aws_dynamodb_table_item" "initial_count" {
  table_name = aws_dynamodb_table.visitor_counter.name
  hash_key   = aws_dynamodb_table.visitor_counter.hash_key

  item = <<ITEM
{
  "id": {"S": "counter"},
  "count": {"N": "0"}
}
ITEM
}



