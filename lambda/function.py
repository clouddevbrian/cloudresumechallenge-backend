import json
import boto3

# Importing dependecies. 

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('crcvisits')

# Indicating what resource, in this case the db and what table I want to access.

def lambda_handler(event, context):
 
    output = table.get_item(
    Key={
        'name' : 'visitors',
    })

# Here I've pulled the data from the row which had the key ID of name:visitors.
# Item allows me to determine exactly what attribute, in this case "count".
    
    count = output['Item']['count']
    count = count + 1
    print(count)
    output = table.put_item(
        Item={
        'name' : 'visitors',
        'count' : count
    })

    return count

"""
Above I create a variable from the output of the 'Item' value of "count" from..
the matching key ID above. Then I add +1 to this variable value.

Then I action the counter into the db by using the put_item command to insert
the variable into the "count" field again with the matching key ID.
The return function ends the logic and outputs the final value for us.