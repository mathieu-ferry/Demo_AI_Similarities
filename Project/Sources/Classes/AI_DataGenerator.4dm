property customerExpectedSchema : Object
property addressExpectedSchema : Object
property singleCustomerExpectedSchema : Object
property customerColExpectedSchema : Collection
property addressColExpectedSchema : Collection
property customerSystemPrompt : Text
property addressSystemPrompt : Text
property singleCustomerSystemPrompt : Text
property customerGenBot : cs.AIKit.OpenAIChatHelper
property responseData : Text
property UICallback_onData : 4D.Function
property UICallback_onTerminate : 4D.Function
property generated : Integer
property alreadyThere : Integer
property quantityBy : Integer
property quantity : Integer

Class extends AI_Agent


singleton Class constructor()
	Super()
	//This.setAgent($providerName; $model)
	This.responseData:=""
	This.addressExpectedSchema:={streetNumber: "number as string"; streetName: "street name"; apartment: "number as string"; builing: "building"; poBox: "po box"; city: "city"; region: "region"; postalCode: "postal code as string"; country: "country"}
	This.customerExpectedSchema:={firstname: "firstname"; lastname: "lastname"; email: "firstname.lastname@randomdomain.com"; phone: "random phone number as string"; address: This.addressExpectedSchema}
	
	This.customerColExpectedSchema:=[This.customerExpectedSchema]
	This.addressColExpectedSchema:=[This.addressColExpectedSchema]
	This.singleCustomerExpectedSchema:=OB Copy(This.customerExpectedSchema)
	This.singleCustomerExpectedSchema.address:=OB Copy(This.addressExpectedSchema)
	
	This.customerSystemPrompt:="You are a data generating assistant. Your answers are used to populate a database. Your answers are stricly JSON formatted, no greetings, no conclusion, just pure json."+\
		"I will ask you to generate json arrays to populate a customer table. "+\
		"I will just ask you to generate a certain amount of records, and you will provide me the answer as a json array. "+\
		"The json array must have the following schema, here provided for 1 customer: "+JSON Stringify(This.customerExpectedSchema)+". "+\
		"avoid generic names like john doe, prefer realistic ones. "+\
		"avoid generic email domains like example.com, prefer realistic ones."
	This.addressSystemPrompt:="You are a data generating assistant. Your answers are used to populate a database. Your answers are stricly JSON formatted, no greetings, no conclusion, just pure json."+\
		"I will ask you to generate json arrays of structured address objects. "+\
		"I will just ask you to generate a certain amount of records, and you will provide me the answer as a json array. "+\
		"The json array must have the following schema, here provided for 1 address: "+JSON Stringify(This.addressExpectedSchema)+". "+\
		"Note that not all address attributes are mandatory."
	This.singleCustomerSystemPrompt:="You are a data generating assistant. Your answers are used to populate a database. Your answers are stricly JSON formatted, no greetings, no conclusion, just pure json."+\
		"I will ask you to generate a json object to populate a customer table. "+\
		"The json object must have the following schema: "+JSON Stringify(This.singleCustomerExpectedSchema)+". "+\
		"avoid generic names like john doe, prefer realistic ones. "+\
		"avoid generic email domains like example.com, prefer realistic ones. "+\
		"Note that not all address attributes are mandatory."
	
Function generateRandomCustomerObject() : Object
	var $customerGenBot : cs.AIKit.OpenAIChatHelper
	var $addressGenBot : cs.AIKit.OpenAIChatHelper
	var $prompt : Text
	var $AIResponse : Object
	var $result : Object
	
	$customerGenBot:=This.AIClient.chat.create(This.singleCustomerSystemPrompt; {model: This.model})
	$prompt:="generate 1 customer"
	$AIResponse:=$customerGenBot.prompt($prompt)
	$result:=This.getAIStructuredResponse($AIResponse; Is object)
	If ($result.success)
		return $result.response
	Else 
		return {}
	End if 
	
Function generateRandomCustomer() : cs.customerEntity
	var $customerObject : Object
	
	$customerObject:=This.generateRandomCustomerObject()
	return ds.customer.newCustomerFromObject($customerObject)
	
	
Function generateData()
	This.generateCustomers(30; 10)
	This.populateAddresses(10)
	
Function populateAddresses($quantityBy : Integer; $callback : Object)
	var $addressGenBot : cs.AIKit.OpenAIChatHelper
	var $customers : cs.customerSelection
	var $customer : cs.customerEntity
	var $addresses : Collection:=[]
	var $prompt : Text
	var $AIResponse : Object
	var $result : Object
	var $failedAttempts : Integer:=0
	var $maxFailedAttempts : Integer:=10
	var $total : Integer
	var $populated : Integer
	var $progress : Object
	
	$addressGenBot:=This.AIClient.chat.create(This.addressSystemPrompt; {model: This.model})
	
	$customers:=ds.customer.all().query("address = null")
	$total:=$customers.length
	$populated:=0
	$progress:={}
	
	For each ($customer; $customers) While ($failedAttempts<=10)
		If ($customer.address=Null)
			While (($addresses.length=0) && ($failedAttempts<=10))
				$prompt:="generate "+String($quantityBy)+" addresses"
				$AIResponse:=$addressGenBot.prompt($prompt)
				$result:=This.getAIStructuredResponse($AIResponse; Is collection)
				If ($result.success)
					$addresses:=$result.response
				Else 
					$failedAttempts+=1
				End if 
			End while 
			
			If ($addresses.length>0)
				$customer.address:=cs.address.new($addresses.pop())
				$customer.save()
				If ($callback#Null)
					$populated+=1
					$progress.value:=Int($populated/$total*100)
					$progress.message:="Populating addresses "+String($populated)+"/"+String($total)
					CALL FORM($callback.window; $callback.formula; $progress)
				End if 
			End if 
		End if 
	End for each 
	
Function generateCustomers($quantity : Integer; $quantityBy : Integer; $callback : Object)
	var $customerGenBot : cs.AIKit.OpenAIChatHelper
	var $alreadyThere : Integer
	var $generated : Integer:=0
	var $toGenerate : Integer
	var $prompt : Text
	var $AIResponse : Object
	var $result : Object
	var $customers : Collection
	var $failedAttempts : Integer:=0
	var $maxFailedAttempts : Integer:=10
	var $progress : Object
	
	$progress:={}
	$customerGenBot:=This.AIClient.chat.create(This.customerSystemPrompt; {model: This.model})
	$alreadyThere:=ds.customer.all().length
	
	While (($generated<$quantity) && ($failedAttempts<=$maxFailedAttempts))
		$toGenerate:=($quantityBy<($quantity-$generated)) ? $quantityBy : ($quantity-$generated)
		$prompt:="generate "+String($toGenerate)+" customers"
		$AIResponse:=$customerGenBot.prompt($prompt)
		$result:=This.getAIStructuredResponse($AIResponse; Is collection)
		If ($result.success)
			ds.customer.fromCollection($result.response)
			$generated:=ds.customer.all().length-$alreadyThere
			
			If ($callback#Null)
				$progress.value:=Int($generated/$quantity*100)
				$progress.message:="Generating customers "+String($generated)+"/"+String($quantity)
				CALL FORM($callback.window; $callback.formula; $progress)
			End if 
		Else 
			$failedAttempts+=1
		End if 
	End while 
	
	
Function anotherOnData($result : cs.AIKit.OpenAIChatCompletionsResult)
	
	
	If ($result.success)
		cs.AI_DataGenerator.me.responseData+=$result.choice.delta.text
		cs.AI_DataGenerator.me.UICallback_onData.call(Form; $result.choice.delta.text)
	End if 
	
Function anotherOnTerminate($result : cs.AIKit.OpenAIChatCompletionsResult)
	var $AIResponse : Object
	var $item : Object
	var $customer : cs.customerEntity
	var $prompt : Text
	var $toGenerate : Integer
	
	If ($result.success)
		cs.AI_DataGenerator.me.responseData+=$result.choice.delta.text
		cs.AI_DataGenerator.me.UICallback_onData.call(Form; $result.choice.delta.text)
		cs.AI_DataGenerator.me.UICallback_onData.call(Form; "\n")
		
		$AIResponse:=cs.AI_DataGenerator.me.getAIStructuredResponseFromText(cs.AI_DataGenerator.me.responseData; Is collection)
		If ($AIResponse.success)
			For each ($item; $AIResponse.response)
				$customer:=ds.customer.newCustomerFromObject($item)
				$customer.save()
			End for each 
		Else 
		End if 
		
		cs.AI_DataGenerator.me.generated:=ds.customer.all().length-cs.AI_DataGenerator.me.alreadyThere
		If (cs.AI_DataGenerator.me.generated<cs.AI_DataGenerator.me.quantity)
			cs.AI_DataGenerator.me.responseData:=""
			$toGenerate:=(cs.AI_DataGenerator.me.quantityBy<(cs.AI_DataGenerator.me.quantity-cs.AI_DataGenerator.me.generated)) ? cs.AI_DataGenerator.me.quantityBy : (cs.AI_DataGenerator.me.quantity-cs.AI_DataGenerator.me.generated)
			$prompt:="generate "+String($toGenerate)+" customers"
			cs.AI_DataGenerator.me.UICallback_onData.call(Form; "prompt : "+$prompt+"\n\n")
			cs.AI_DataGenerator.me.customerGenBot.prompt($prompt)
			
		Else 
			cs.AI_DataGenerator.me.UICallback_onTerminate.call(Form; "prompt : "+$prompt+"\n\n")
		End if 
		
		
	End if 
	
	
	
Function generateCustomersAsync($quantity : Integer; $quantityBy : Integer; $callback : Object)
	var $toGenerate : Integer
	var $prompt : Text
	var $failedAttempts : Integer:=0
	var $maxFailedAttempts : Integer:=10
	var $progress : Object
	var $options : cs.AIKit.OpenAIChatCompletionsParameters
	
	This.generated:=0
	This.quantity:=$quantity
	This.quantityBy:=$quantityBy
	This.responseData:=""
	This.alreadyThere:=ds.customer.all().length
	$toGenerate:=(This.quantityBy<(This.quantity-This.generated)) ? This.quantityBy : (This.quantity-This.generated)
	
	$options:=cs.AIKit.OpenAIChatCompletionsParameters.new()
	$options.stream:=True
	
	// with the chat helper, callbacks seems to be inverted
	$options.onResponse:=This.anotherOnTerminate
	$options.onTerminate:=This.anotherOnData
	
	This.UICallback_onData:=$callback.onData
	This.UICallback_onTerminate:=$callback.onData
	
	$options.model:=This.model
	
	$progress:={}
	This.customerGenBot:=This.AIClient.chat.create(This.customerSystemPrompt; $options)
	
	$prompt:="generate "+String($toGenerate)+" customers"
	
	This.UICallback_onData.call(Form; "prompt : "+$prompt+"\n\n")
	
	This.customerGenBot.prompt($prompt)
	
	
	
	
	
	
	
	
	
	
	