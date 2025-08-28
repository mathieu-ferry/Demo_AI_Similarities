property model : Text
property provider : Text
property AIClient : cs.AIKit.OpenAI


Class constructor()
/*
Class constructor($providerName : Text; $model : Text)
var $provider : cs.providerSettingsEntity
var $AIClient : cs.AIKit.OpenAI
	
$provider:=ds.providerSettings.query("name = :1"; $providerName).first()
	
This.provider:=$providerName
This.model:=$model
This.AIClient:=cs.AIKit.OpenAI.new($provider.key)
If ($provider.url#"")
This.AIClient.baseURL:=$provider.url
End if 
*/
	
	
Function setAgent($providerName : Text; $model : Text)
	var $provider : cs.providerSettingsEntity
	var $AIClient : cs.AIKit.OpenAI
	
	$provider:=ds.providerSettings.query("name = :1"; $providerName).first()
	
	This.provider:=$providerName
	This.model:=$model
	This.AIClient:=cs.AIKit.OpenAI.new($provider.key)
	If ($provider.url#"")
		This.AIClient.baseURL:=$provider.url
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
	End if 
	
	return {success: True; response: $response; kind: $expectedFormat; error: Null}
	
	
Function getAIStructuredResponseFromText($AIresponse : Text; $expectedFormat : Integer) : Object
	var $jsonContent : Text
	var $charStart : Text:=""
	var $jsonStart : Integer
	var $returnObject : Object:={}
	var $response : Variant
	
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
	
	If ($charStart="")  //$charStart can either be "" or "{" or "["
		return {success: True; response: $AIresponse; kind: $expectedFormat; error: Null}
	End if 
	
	$jsonStart:=Position($charStart; $AIresponse)
	If ($jsonStart>0)
		$jsonContent:=Substring($AIresponse; $jsonStart)
		$response:=Try(JSON Parse($jsonContent; $expectedFormat))
		If ($response=Null)
			return {success: False; response: Null; kind: Null; error: "Could not parse AIResponse with the expected format"}
		End if 
	End if 
	
	return {success: True; response: $response; kind: $expectedFormat; error: Null}
	