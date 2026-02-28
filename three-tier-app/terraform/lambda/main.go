package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

var ddb *dynamodb.Client

func init() {
	cfg, err := config.LoadDefaultConfig(
		context.TODO(),
		config.WithRegion(os.Getenv("REGION")),
	)

	if err != nil {
		panic(fmt.Sprintf("unable to load AWS config: %v", err))
	}

	ddb = dynamodb.NewFromConfig(cfg)
}

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	userId, ok := request.QueryStringParameters["userId"]
	if !ok || userId == "" {
		return respond(400, map[string]string{"message": "Missing userId parameter"})
	}

	result, err := ddb.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(os.Getenv("TABLE_NAME")),
		Key: map[string]types.AttributeValue{
			"userId": &types.AttributeValueMemberS{Value: userId},
		},
	})
	if err != nil {
		fmt.Printf("Unable to retrieve data: %v\n", err)
		return respond(500, map[string]string{"message": "Failed to retrieve user data"})
	}

	if result.Item == nil {
		return respond(404, map[string]string{"message": "No user data found"})
	}

	item := make(map[string]string)
	for k, v := range result.Item {
		if s, ok := v.(*types.AttributeValueMemberS); ok {
			item[k] = s.Value
		}
	}

	return respond(200, item)
}

func respond(status int, body interface{}) (events.APIGatewayProxyResponse, error) {
	jsonBody, _ := json.Marshal(body)
	return events.APIGatewayProxyResponse{
		StatusCode: status,
		Body:       string(jsonBody),
		Headers:    map[string]string{"Content-Type": "application/json"},
	}, nil
}

func main() {
	lambda.Start(handler)
}
