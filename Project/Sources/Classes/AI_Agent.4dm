property model : Text
property provider : Text
property AIClient : cs.AIKit.OpenAI

Class constructor()
	This.model:=""
	This.provider:=""
	
Function setAgent($providerName : Text; $model : Text)
	var $provider : cs.providerSettingsEntity
	var $AIClient : cs.AIKit.OpenAI
	
	//Fixme: checkif provider still exists
	
	If ((This.provider#$providerName) || (This.model#$model))
		$provider:=ds.providerSettings.query("name = :1"; $providerName).first()
		
		If ($provider=Null)
			throw(999; "Provider is not set in settings")
			return 
		End if 
		
		This.provider:=$providerName
		This.model:=$model
		This.AIClient:=cs.AIKit.OpenAI.new($provider.key)
		If ($provider.url#"")
			This.AIClient.baseURL:=$provider.url
		End if 
	End if 
	
Function getAIStructuredResponse($AIresponse : Object; $expectedFormat : Integer) : Object
	var $jsonContent : Text
	var $charStart : Text:=""
	var $jsonStart : Integer
	var $returnObject : Object:={}
	var $response : Variant
	
	Case of 
		: (($AIresponse.errors#Null) && ($AIresponse.errors.length#0))
			//: (($AIresponse.choice=Null) || (Undefined($AIresponse.choice.message.content)))
			$returnObject.success:=False
			$returnObject.response:=Null
			$returnObject.kind:=Null
			If (Undefined($AIresponse.errors[0].message))
				$returnObject.error:="Provider error message not available"
			Else 
				$returnObject.error:=$AIresponse.errors[0].message
			End if 
			
			return $returnObject
			
		: ($expectedFormat=Is object)
			$charStart:="{"
			
		: ($expectedFormat=Is collection)
			$charStart:="["
			
		: ($expectedFormat=Is text)
			$charStart:=""
			
		Else 
			return {success: False; response: Null; kind: Null; error: "Expected format must be one the constant 'is object' or 'is collection' or 'is text'"}
	End case 
	
	If ($charStart="")  //$charStart can either be "" or "{" or "["
		return {success: True; response: $AIresponse.choice.message.content; kind: $expectedFormat; error: Null}
	End if 
	
	$jsonStart:=Position($charStart; $AIresponse.choice.message.content)
	If ($jsonStart>0)
		$jsonContent:=Substring($AIresponse.choice.message.content; $jsonStart)
		$response:=Try(JSON Parse($jsonContent; $expectedFormat))
		If ($response=Null)
			return {success: False; response: Null; kind: Null; error: "Could not parse AIResponse with the expected format"}
		End if 
	Else 
		return {success: False; response: Null; kind: Null; error: "Could not parse AIResponse with the expected format"}
	End if 
	
	return {success: True; response: $response; kind: $expectedFormat; error: Null}
	
	
Function getAIStructuredResponseFromText($AIresponse : Text; $expectedFormat : Integer) : Object
	var $jsonContent : Text
	var $charStart : Text:=""
	var $jsonStart : Integer
	var $returnObject : Object:={}
	var $response : Variant
	var $thinkStart : Integer
	var $thinkEnd : Integer
	
	Case of 
			
		: ($expectedFormat=Is object)
			$charStart:="{"
			
		: ($expectedFormat=Is collection)
			$charStart:="["
			
		: ($expectedFormat=Is text)
			$charStart:=""
			
		Else 
			return {success: False; response: Null; kind: Null; error: "Expected format must be one the constant 'is object' or 'is collection' or 'is text'"}
	End case 
	
	If ($expectedFormat=Is text)
		return {success: True; response: $AIresponse; kind: $expectedFormat; error: Null}
	End if 
	
	//Remove <think> </think> part of the answer, from some well known llms
	$thinkStart:=Position("<think>"; $AIresponse)
	If ($thinkStart>0)
		$thinkEnd:=Position("</think>"; $AIresponse)
		If ($thinkEnd>0)
			$AIresponse:=Delete string($AIresponse; $thinkStart; $thinkEnd+Length("</think>")-$thinkStart)
		End if 
	End if 
	
	
	$jsonStart:=Position($charStart; $AIresponse)
	If ($jsonStart>0)
		$jsonContent:=Substring($AIresponse; $jsonStart)
		$response:=Try(JSON Parse($jsonContent; $expectedFormat))
		If ($response=Null)
			return {success: False; response: Null; kind: Null; error: "Could not parse AIResponse with the expected format"}
		End if 
	Else 
		return {success: False; response: Null; kind: Null; error: "Could not parse AIResponse with the expected format"}
	End if 
	
	Case of 
		: (($expectedFormat=Is collection) && ($response.length>0) && (Value type($response.first())=Is object))
			return {success: True; response: $response; kind: $expectedFormat; error: Null}
			
		: (($expectedFormat=Is object) && (Value type($response)=Is object))
			return {success: True; response: $response; kind: $expectedFormat; error: Null}
		Else 
			return {success: False; response: Null; kind: Null; error: "Could not parse AIResponse with the expected format"}
	End case 
	
	