#!/bin/bash

# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider

# 1. Setup repo
git clone https://github.com/hashicorp/terraform-provider-scaffolding-framework --depth 1 terraform-provider-hashicups

cd terraform-provider-hashicups

go mod edit -module terraform-provider-hashicups

go mod tidy

# Open the main.go file in the terraform-provider-hashicups repository's root directory and replace the import declaration with the following.
# import (
#     "context"
#     "flag"
#     "log"

#     "github.com/hashicorp/terraform-plugin-framework/providerserver"

#     "terraform-provider-hashicups/internal/provider"
# )

# Create a docker_compose directory in the repository you cloned, which will contain the Docker configuration required to launch a local instance of HashiCups.
mkdir docker_compose

# Create a docker_compose/conf.json file with the following.
cat << EOL > docker_compose/conf.json
{
  "db_connection": "host=db port=5432 user=postgres password=password dbname=products sslmode=disable",
  "bind_address": "0.0.0.0:9090",
  "metrics_address": "localhost:9102"
}
EOL

# Create a docker_compose/docker-compose.yml file with the following.
cat << EOL > docker_compose/docker-compose.yml
version: '3.7'
services:
  api:
    image: "hashicorpdemoapp/product-api:v0.0.22"
    ports:
      - "19090:9090"
    volumes:
      - ./conf.json:/config/config.json
    environment:
      CONFIG_FILE: '/config/config.json'
    depends_on:
      - db
  db:
    image: "hashicorpdemoapp/product-api-db:v0.0.22"
    ports:
      - "15432:5432"
    environment:
      POSTGRES_DB: 'products'
      POSTGRES_USER: 'postgres'
      POSTGRES_PASSWORD: 'password'
EOL

# Implement initial provider type
# Open the internal/provider/provider.go file and replace the existing code with the following.
# See for the detail step: https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider#implement-initial-provider-type

# Implement the provider server
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider#implement-initial-provider-type

# Verify the initial provider
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider#verify-the-initial-provider
go run main.go

# Prepare Terraform for local provider install
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider#prepare-terraform-for-local-provider-install

export GOBIN=$HOME/go/bin

cat << EOL > ~/.terraformrc
provider_installation {

  dev_overrides {
      "hashicorp.com/edu/hashicups" = "$HOME/go/bin"
  }

  # For all other providers, install them directly from their origin provider
  # registries as normal. If you omit this, Terraform will _only_ use
  # the dev_overrides block, and so no other providers will be available.
  direct {}
}
EOL

# Locally install provider and verify with Terraform
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider#locally-install-provider-and-verify-with-terraform
go install .
# Create an examples/provider-install-verification directory, which will contain a terraform configuration to verify local provider installation, and navigate to it.
mkdir examples/provider-install-verification && cd "$_"
# Create a main.tf file with the following.
cat << EOL > main.tf
terraform {
  required_providers {
    hashicups = {
      source = "hashicorp.com/edu/hashicups"
    }
  }
}

provider "hashicups" {}

data "hashicups_coffees" "example" {}
EOL

# Run a Terraform plan with the non-existent data source. Terraform will respond with the missing data source (hashicups_coffees) error.
terraform plan

# Navigate to the terraform-provider-hashicups directory.
cd ../..

# 2. Implement provider schema
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider-configure#implement-provider-schema

# Implement provider data model
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider-configure#implement-provider-data-model

# Implement client configuration functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider-configure#implement-client-configuration-functionality
# Do not forget to add github.com/hashicorp-demoapp/hashicups-client-go v0.1.0 to go.mod and run go mod tidy

# Start HashiCups locally
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider-configure#start-hashicups-locally
cd docker_compose
# Run docker-compose up to spin up a local instance of HashiCups on port 19090.
docker-compose up
# In the original terminal window, verify that HashiCups is running by sending a request to its health check endpoint. The HashiCups service will respond with ok.
curl localhost:19090/health/readyz

# Create a HashiCups user
# Create a user on HashiCups named education with the password test123.
curl -X POST localhost:19090/signup -d '{"username":"education", "password":"test123"}'

# Set the HASHICUPS_TOKEN environment variable to the token you retrieved from invoking the /signup endpoint. You will use this in later tutorials.
export HASHICUPS_TOKEN=ey...

# If you are in another terminal, please set GOBIN path
export GOBIN=$HOME/go/bin

# 3. Implement temporary data source
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider-configure#implement-temporary-data-source
cat << EOL > internal/provider/coffees_data_source.go
package provider

import (
    "context"

    "github.com/hashicorp/terraform-plugin-framework/datasource"
    "github.com/hashicorp/terraform-plugin-framework/datasource/schema"
)

func NewCoffeesDataSource() datasource.DataSource {
    return &coffeesDataSource{}
}

type coffeesDataSource struct{}

func (d *coffeesDataSource) Metadata(_ context.Context, req datasource.MetadataRequest, resp *datasource.MetadataResponse) {
    resp.TypeName = req.ProviderTypeName + "_coffees"
}

func (d *coffeesDataSource) Schema(_ context.Context, _ datasource.SchemaRequest, resp *datasource.SchemaResponse) {
    resp.Schema = schema.Schema{}
}

func (d *coffeesDataSource) Read(ctx context.Context, req datasource.ReadRequest, resp *datasource.ReadResponse) {
}
EOL

# Verify provider configuration
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider-configure#verify-provider-configuration
cd examples/provider-install-verification

# The main.tf Terraform configuration file in this directory has no provider configuration values in the Terraform configuration.
# Run a Terraform plan with missing provider configuration. Terraform will report errors for the missing provider configuration values.
terraform plan

# Run a Terraform plan with environment variables.
HASHICUPS_HOST=http://localhost:19090 \
  HASHICUPS_USERNAME=education \
  HASHICUPS_PASSWORD=test123 \
  terraform plan

# The terminal containing your HashiCups logs will record the sign in operation.
# api_1  | 2020-12-10T09:19:50.601Z [INFO]  Handle User | signin

# Verify the Terraform configuration behavior by setting the provider schema-defined host, username, and password values in a Terraform configuration.
# Create an examples/coffees directory and navigate to it.
mkdir ../coffees && cd "$_"
# Create a main.tf Terraform configuration file in this directory that sets provider configuration values in the Terraform configuration.
cat << EOL > main.tf
terraform {
  required_providers {
    hashicups = {
      source = "hashicorp.com/edu/hashicups"
    }
  }
}

provider "hashicups" {
  host     = "http://localhost:19090"
  username = "education"
  password = "test123"
}

data "hashicups_coffees" "edu" {}
EOL

# Run a Terraform plan. Terraform will authenticate with your HashiCups instance using the values from the provider block and once again report that it is able to read from the hashicups_coffees.example data source.
terraform plan

# Remove temporary data source
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider-configure#remove-temporary-data-source
# Remove the internal/provider/coffees_data_source.go file.
rm internal/provider/coffees_data_source.go
# Open the internal/provider/provider.go file.
# Remove the data source from your provider's schema by replacing the DataSources method with the following.

# 4. Implement data source
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-data-source-read

# Implement initial data source type
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-data-source-read#implement-initial-data-source-type

cat << EOL > internal/provider/coffees_data_source.go
package provider

import (
  "context"

  "github.com/hashicorp/terraform-plugin-framework/datasource"
  "github.com/hashicorp/terraform-plugin-framework/datasource/schema"
)

// Ensure the implementation satisfies the expected interfaces.
var (
  _ datasource.DataSource = &coffeesDataSource{}
)

// NewCoffeesDataSource is a helper function to simplify the provider implementation.
func NewCoffeesDataSource() datasource.DataSource {
  return &coffeesDataSource{}
}

// coffeesDataSource is the data source implementation.
type coffeesDataSource struct{}

// Metadata returns the data source type name.
func (d *coffeesDataSource) Metadata(_ context.Context, req datasource.MetadataRequest, resp *datasource.MetadataResponse) {
  resp.TypeName = req.ProviderTypeName + "_coffees"
}

// Schema defines the schema for the data source.
func (d *coffeesDataSource) Schema(_ context.Context, _ datasource.SchemaRequest, resp *datasource.SchemaResponse) {
  resp.Schema = schema.Schema{}
}

// Read refreshes the Terraform state with the latest data.
func (d *coffeesDataSource) Read(ctx context.Context, req datasource.ReadRequest, resp *datasource.ReadResponse) {
}
EOL

# Add data source to provider
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-data-source-read#add-data-source-to-provider

# Implement data source client functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-data-source-read#implement-data-source-client-functionality

# Implement data source schema
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-data-source-read#implement-data-source-schema

# Implement data source data models
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-data-source-read#implement-data-source-data-models

# Implement read functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-data-source-read#implement-read-functionality
# Build and install the updated provider.
go install .

# Verify data source
cd examples/coffees

# Run a Terraform plan. Terraform will report the data it retrieved from the HashiCups API.
terraform plan

cd ../..

# 5. Implement logging
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-logging

# Implement log messages
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-logging

# Implement structured log fields
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-logging#implement-structured-log-fields

# Implement log filtering
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-logging#implement-log-filtering

go install .

# View all Terraform log output
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-logging#view-all-terraform-log-output
cd examples/coffees
TF_LOG=TRACE terraform plan

# Save all Terraform log output
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-logging#save-all-terraform-log-output
TF_LOG=TRACE TF_LOG_PATH=trace.txt terraform plan

# View specific Terraform log output
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-logging#view-specific-terraform-log-output
TF_LOG=INFO terraform plan
TF_LOG_PROVIDER=INFO terraform plan

cd ../..

# 6. Implement resource create and read
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-create

# Implement initial resource type
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-create#implement-initial-resource-type
cat << EOL > internal/provider/order_resource.go
package provider

import (
    "context"

    "github.com/hashicorp/terraform-plugin-framework/resource"
    "github.com/hashicorp/terraform-plugin-framework/resource/schema"
)

// Ensure the implementation satisfies the expected interfaces.
var (
    _ resource.Resource = &orderResource{}
)

// NewOrderResource is a helper function to simplify the provider implementation.
func NewOrderResource() resource.Resource {
    return &orderResource{}
}

// orderResource is the resource implementation.
type orderResource struct{}

// Metadata returns the resource type name.
func (r *orderResource) Metadata(_ context.Context, req resource.MetadataRequest, resp *resource.MetadataResponse) {
    resp.TypeName = req.ProviderTypeName + "_order"
}

// Schema defines the schema for the resource.
func (r *orderResource) Schema(_ context.Context, _ resource.SchemaRequest, resp *resource.SchemaResponse) {
    resp.Schema = schema.Schema{}
}

// Create creates the resource and sets the initial Terraform state.
func (r *orderResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
}

// Read refreshes the Terraform state with the latest data.
func (r *orderResource) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
}

// Update updates the resource and sets the updated Terraform state on success.
func (r *orderResource) Update(ctx context.Context, req resource.UpdateRequest, resp *resource.UpdateResponse) {
}

// Delete deletes the resource and removes the Terraform state on success.
func (r *orderResource) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
}
EOL

# Add resource to provider
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-create#add-resource-to-provider

# Implement resource client functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-create#implement-resource-client-functionality
# Ensure that your resource satisfies the Resource and ResourceWithConfigure interfaces defined by the Framework by replacing the var statement with the following.

# Implement resource schema
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-create#implement-resource-client-functionality

# Implement resource data models
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-create#implement-resource-data-models

# Implement create functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-create#implement-create-functionality

# Implement read functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-create#implement-read-functionality

go install .

# Verify resource
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-create#verify-resource
mkdir examples/order && cd "$_"

cat << EOL > main.tf
terraform {
  required_providers {
    hashicups = {
      source  = "hashicorp.com/edu/hashicups"
    }
  }
  required_version = ">= 1.1.0"
}

provider "hashicups" {
  username = "education"
  password = "test123"
  host     = "http://localhost:19090"
}

resource "hashicups_order" "edu" {
  items = [{
    coffee = {
      id = 3
    }
    quantity = 2
    }, {
    coffee = {
      id = 1
    }
    quantity = 2
    }
  ]
}

output "edu_order" {
  value = hashicups_order.edu
}
EOL

# Apply your configuration to craete the order.
terraform apply

# Once the apply completes, the provider saves the resource's details in Terraform's state. View the state by running terraform state show <resource_name>.
terraform state show hashicups_order.edu

cd ../..

# Verify order created
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-create#verify-order-created
# When you create an order in HashiCups using Terraform, the terminal containing your HashiCups logs will have recorded operations invoked by the HashiCups Provider. Switch to that terminal to review the log messages.
# api_1  | 2021-07-22T10:26:31.179Z [INFO]  Handle User | signin
# api_1  | 2021-07-22T10:26:51.179Z [INFO]  Handle User | signin
# api_1  | 2021-07-22T10:26:51.195Z [INFO]  Handle Orders | CreateOrder

# Verify that Terraform created the order by retrieving the order details via the API.
curl -X GET  -H "Authorization: ${HASHICUPS_TOKEN}" localhost:19090/orders/1

# 7. Implement resource update
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-update

# Verify schema and model
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-update#verify-schema-and-model

# Implement update functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-update#implement-update-functionality

go install .

# Verify update functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-update#verify-update-functionality
cd examples/order

# Replace your hashicups_order.edu resource in examples/order/main.tf. This configuration changes the drinks and quantities in the order.
# resource "hashicups_order" "edu" {
#   items = [{
#     coffee = {
#       id = 3
#     }
#     quantity = 2
#     },
#     {
#       coffee = {
#         id = 2
#       }
#       quantity = 3
#   }]
# }

terraform plan
# Note that the id attribute is showing a plan difference where the value is going from the known value to an unknown value ((known after apply)).

# Enhance plan output
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-update#enhance-plan-output
cd ../..
go install .

# Verify update functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-update#verify-update-functionality-1
cd examples/order
# Run a Terraform apply to update your order. The plan will not mark the id attribute as (known after apply) any longer. Your provider will update your order and set a new value for the last_updated attribute.
terraform apply -auto-approve
# Verify that the provider updated your order by invoking the HashiCups API.
curl -X GET -H "Authorization: ${HASHICUPS_TOKEN}" localhost:19090/orders/1

cd ../..

# 8. Implement resource delete
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-delete

# Implement delete functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-delete#implement-delete-functionality

go install .

# Verify delete functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-delete#verify-delete-functionality
cd examples/order
# Destroy the configuration. This will delete your order.
terraform destroy -auto-approve
# Verify that the provider deleted your order by invoking the HashiCups API. Substitute the order number with your order ID and the auth token with your auth token.
curl -X GET -H "Authorization: ${HASHICUPS_TOKEN}" localhost:19090/orders/1

cd ../..

# 9. Implement resource import
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-import

# Implement import functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-import#implement-import-functionality
go install .

# Verify import functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-resource-import#verify-import-functionality
cd examples/order
# Apply this configuration to ensure that the HashiCups API contains an order.
terraform apply -auto-approve
# Retrieve the order ID from the Terraform state. You will use this order ID to import the order in the next step.
terraform show
# Remove the existing order from Terraform's state. The order will still exist in the HashiCups API.
terraform state rm hashicups_order.edu
# Verify that the Terraform state no longer contains the order resource. The previous edu_order output value will still remain.
terraform show
# Verify that the HashiCups API still has your order. If needed, replace 2 with the order ID from the output of the terraform show command.
curl -X GET -H "Authorization: ${HASHICUPS_TOKEN}" localhost:19090/orders/2
# Import the existing HashiCups API order into Terraform. Replace the order ID with your order ID.
terraform import hashicups_order.edu 2
# Verify that the Terraform state contains the order again.
terraform show

cd ../..

# 10. Implement a function
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-functions

# Implement the function
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-functions#implement-the-function
cat << EOL > internal/provider/compute_tax_function.go
package provider

import (
    "math"
    "context"
    "github.com/hashicorp/terraform-plugin-framework/function"
)

// Ensure the implementation satisfies the desired interfaces.
var _ function.Function = &ComputeTaxFunction{}

type ComputeTaxFunction struct{}

func NewComputeTaxFunction() function.Function {
    return &ComputeTaxFunction{}
}

func (f *ComputeTaxFunction) Metadata(ctx context.Context, req function.MetadataRequest, resp *function.MetadataResponse) {
    resp.Name = "compute_tax"
}

func (f *ComputeTaxFunction) Definition(ctx context.Context, req function.DefinitionRequest, resp *function.DefinitionResponse) {
    resp.Definition = function.Definition{
        Summary:     "Compute tax for coffee",
        Description: "Given a price and tax rate, return the total cost including tax.",
    Parameters: []function.Parameter{
            function.Float64Parameter{
                Name:        "price",
                Description: "Price of coffee item.",
            },
            function.Float64Parameter{
                Name:        "rate",
                Description: "Tax rate. 0.085 == 8.5%",
            },
        },
        Return: function.Float64Return{},
    }
}

func (f *ComputeTaxFunction) Run(ctx context.Context, req function.RunRequest, resp *function.RunResponse) {
    var price float64
    var rate float64
    var total float64

    // Read Terraform argument data into the variables
    resp.Error = function.ConcatFuncErrors(resp.Error, req.Arguments.Get(ctx, &price, &rate))

    total = math.Round((price + price * rate) * 100) / 100;

    // Set the result
    resp.Error = function.ConcatFuncErrors(resp.Error, resp.Result.Set(ctx, total));
}
EOL

go install .

# Verify the function
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-functions#verify-the-function
mkdir examples/compute_tax && cd "$_"
cat << EOL > main.tf
terraform {
  required_providers {
    hashicups = {
      source  = "hashicorp.com/edu/hashicups"
    }
  }
  required_version = ">= 1.8.0"
}

provider "hashicups" {
  username = "education"
  password = "test123"
  host     = "http://localhost:19090"
}

output "total_price" {
  value = provider::hashicups::compute_tax(5.00, 0.085)
}
EOL

# You call provider-defined functions with the syntax provider::<PROVIDER_NAME>::<FUNCTION_NAME>(<ARGUMENTS>).
# Apply this configuration to ensure that the compute_tax function returns the total price after tax is applied.
terraform apply -auto-approve

cd ../..

# 11. Implement automated testing
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-acceptance-testing

# Implement data source id attribute
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-acceptance-testing#implement-data-source-id-attribute

# Implement data source acceptance testing
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-acceptance-testing#implement-data-source-acceptance-testing

# Verify data source testing functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-acceptance-testing#verify-data-source-testing-functionality
TF_ACC=1 go test -count=1 -v

# Implement resource testing functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-acceptance-testing#implement-resource-testing-functionality
cat << 'EOL' > order_resource_test.go
package provider

import (
  "testing"

  "github.com/hashicorp/terraform-plugin-testing/helper/resource"
)

func TestAccOrderResource(t *testing.T) {
  resource.Test(t, resource.TestCase{
    ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
    Steps: []resource.TestStep{
      // Create and Read testing
      {
        Config: providerConfig + `
resource "hashicups_order" "test" {
  items = [
    {
      coffee = {
        id = 1
      }
      quantity = 2
    },
  ]
}
`,
        Check: resource.ComposeAggregateTestCheckFunc(
          // Verify number of items
          resource.TestCheckResourceAttr("hashicups_order.test", "items.#", "1"),
          // Verify first order item
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.quantity", "2"),
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.id", "1"),
          // Verify first coffee item has Computed attributes filled.
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.description", ""),
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.image", "/hashicorp.png"),
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.name", "HCP Aeropress"),
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.price", "200"),
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.teaser", "Automation in a cup"),
          // Verify dynamic values have any value set in the state.
          resource.TestCheckResourceAttrSet("hashicups_order.test", "id"),
          resource.TestCheckResourceAttrSet("hashicups_order.test", "last_updated"),
        ),
      },
      // ImportState testing
      {
        ResourceName:      "hashicups_order.test",
        ImportState:       true,
        ImportStateVerify: true,
        // The last_updated attribute does not exist in the HashiCups
        // API, therefore there is no value for it during import.
        ImportStateVerifyIgnore: []string{"last_updated"},
      },
      // Update and Read testing
      {
        Config: providerConfig + `
resource "hashicups_order" "test" {
  items = [
    {
      coffee = {
        id = 2
      }
      quantity = 2
    },
  ]
}
`,
        Check: resource.ComposeAggregateTestCheckFunc(
          // Verify first order item updated
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.quantity", "2"),
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.id", "2"),
          // Verify first coffee item has Computed attributes updated.
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.description", ""),
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.image", "/packer.png"),
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.name", "Packer Spiced Latte"),
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.price", "350"),
          resource.TestCheckResourceAttr("hashicups_order.test", "items.0.coffee.teaser", "Packed with goodness to spice up your images"),
        ),
      },
      // Delete testing automatically occurs in TestCase
    },
  })
}
EOL

# Verify resource testing functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-acceptance-testing#verify-resource-testing-functionality
TF_ACC=1 go test -count=1 -run='TestAccOrderResource' -v

# Implement function testing functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-acceptance-testing#implement-function-testing-functionality
cat << 'EOL' > compute_tax_function_test.go
// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package provider

import (
  "regexp"
  "testing"

  "github.com/hashicorp/terraform-plugin-testing/helper/resource"
  "github.com/hashicorp/terraform-plugin-testing/tfversion"
)

func TestComputeTaxFunction_Known(t *testing.T) {
  resource.UnitTest(t, resource.TestCase{
    TerraformVersionChecks: []tfversion.TerraformVersionCheck{
      tfversion.SkipBelow(tfversion.Version1_8_0),
    },
    ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
    Steps: []resource.TestStep{
      {
        Config: `
        output "test" {
          value = provider::hashicups::compute_tax(5.00, 0.085)
        }
        `,
        Check: resource.ComposeAggregateTestCheckFunc(
          resource.TestCheckOutput("test", "5.43"),
        ),
      },
    },
  })
}

func TestComputeTaxFunction_Null(t *testing.T) {
  resource.UnitTest(t, resource.TestCase{
    TerraformVersionChecks: []tfversion.TerraformVersionCheck{
      tfversion.SkipBelow(tfversion.Version1_8_0),
    },
    ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
    Steps: []resource.TestStep{
      {
        Config: `
        output "test" {
          value = provider::hashicups::compute_tax(null, 0.085)
        }
        `,
        // The parameter does not enable AllowNullValue
        ExpectError: regexp.MustCompile(`argument must not be null`),
      },
    },
  })
}
EOL

# Verify function testing functionality
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-acceptance-testing#verify-function-testing-functionality
TF_ACC=1 go test -count=1 -run='TestComputeTaxFunction' -v

cd ../..

# 12. Implement documentation generation
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-documentation-generation

# Add schema descriptions
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-documentation-generation#add-schema-descriptions

# Review function documentation
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-documentation-generation#review-function-documentation

# Add configuration examples
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-documentation-generation#add-configuration-examples

# Add resource import documentation
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-documentation-generation#add-resource-import-documentation
cat << EOL > examples/resources/hashicups_order/import.sh
# Order can be imported by specifying the numeric identifier.
terraform import hashicups_order.example 123
EOL

# Add function example
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-documentation-generation#add-function-example
mkdir -p examples/functions/compute_tax
cat << EOL > examples/functions/compute_tax/function.tf
# Compute total price with tax
output "total_price" {
  value = provider::hashicups::compute_tax(5.00, 0.085)
}
EOL

# Run documentation generation
# https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-documentation-generation#run-documentation-generation

# Now that you have implemented the documentation generation functionality for your provider, run the go generate ./... command to generate the documentation.
go generate ./...
# View the generated files in the docs directory to verify that the documentation contains the expected descriptions, examples, and schema information.