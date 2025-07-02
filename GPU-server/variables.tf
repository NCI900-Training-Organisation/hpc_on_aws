# -----------------------------------------------------
# Input Variable Declaration: instance_name
# -----------------------------------------------------
variable "instance_name" {
  # A human-readable explanation of what this variable is for.
  # In this case, it is used to set the 'Name' tag on the EC2 instance.
  description = "Value of the Name tag for the EC2 instance"

  # The expected type for this variable (a plain string).
  type = string

  # The default value to use if no value is provided in a .tfvars file
  # or via the command line. This means the variable is optional.
  default = "ExampleAppServerInstance"
}
