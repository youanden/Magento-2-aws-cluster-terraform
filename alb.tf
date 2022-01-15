


/////////////////////////////////////////////////[ APPLICATION LOAD BALANCER ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Application Load Balancers
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb" "this" {
  name               = "${var.app["brand"]}-alb"
  internal           = false
  load_balancer_type = "application"
  drop_invalid_header_fields = true
  security_groups    = [aws_security_group.alb.id]
  subnets            = values(aws_subnet.this).*.id
  access_logs {
    bucket  = aws_s3_bucket.this["system"].bucket
    prefix  = "${var.app["brand"]}-alb"
    enabled = true
  }
  tags = {
    Name = "${var.app["brand"]}-alb"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Target Groups for Load Balancers
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_target_group" "this" {
  for_each    = var.ec2
  name        = "${var.app["brand"]}-${each.key}-target"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  health_check {
    path = "/${random_string.this["health_check"].result}"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create default listener for Load Balancer - default response
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener" "default" {
													   
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"
															
													 
  default_action {
    type             = "fixed-response"
    fixed_response {
        content_type = "text/plain"
        message_body = "No targets are responding to this request"
        status_code  = "502"
        }
    }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create conditional listener rule for Load Balancer - forward to frontend
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener_rule" "frontend" {
  listener_arn = aws_lb_listener.default.arn
  priority     = 30
							
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["frontend"].arn
  }
  condition {
    host_header {
      values = [var.app["domain"]]
    }
  }
  condition {
    http_header {
      http_header_name = "X-Magenx-Header"
      values           = [random_uuid.this.result]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create conditional listener rule for Load Balancer - forward to admin
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener_rule" "admin" {
  listener_arn = aws_lb_listener.default.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["admin"].arn
  }
  condition {
    http_header {
      http_header_name = "X-Magenx-Header"
      values           = [random_uuid.this.result]
    }
  }
  condition {
    path_pattern {
      values = ["/admin_${random_string.this["admin_path"].result}/*"]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create conditional listener rule for Load Balancer - forward to phpmyadmin
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener_rule" "mysql" {
  listener_arn = aws_lb_listener.default.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["admin"].arn
  }
  condition {
    http_header {
      http_header_name = "X-Magenx-Header"
      values           = [random_uuid.this.result]
    }
  }
  condition {
    path_pattern {
      values = ["/mysql_${random_string.this["mysql_path"].result}/*"]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create conditional listener rule for Load Balancer - forward to staging
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener_rule" "staging" {
  listener_arn = aws_lb_listener.default.arn
  priority     = 40
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["staging"].arn
  }
  condition {
    host_header {
	values = [var.app["staging_domain"]]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch HTTP 5XX metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "httpcode_target_5xx_count" {
  alarm_name          = "${var.app["brand"]}-http-5xx-errors-from-target"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb["5xx_threshold"]
  alarm_description   = "HTTPCode 5XX count for frontend instances over ${var.alb["5xx_threshold"]}"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]
  
  dimensions = {
    TargetGroup  = aws_lb_target_group.this["frontend"].arn
    LoadBalancer = aws_lb.this.arn
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch HTTP 5XX metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "httpcode_elb_5xx_count" {
  alarm_name          = "${var.app["brand"]}-http-5xx-errors-from-loadbalancer"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb["5xx_threshold"]
  alarm_description   = "HTTPCode 5XX count for loadbalancer over ${var.alb["5xx_threshold"]}"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]
  
  dimensions = {
    LoadBalancer = aws_lb.this.arn
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch RequestCount metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "alb_rps" {
  alarm_name          = "${var.app["brand"]}-loadbalancer-rps"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = "120"
  statistic           = "Sum"
  threshold           = var.alb["rps_threshold"]
  alarm_description   = "The number of requests processed over 2 minutes greater than ${var.alb["rps_threshold"]}"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]

  dimensions = {
    LoadBalancer = aws_lb.this.arn
  }
}