Class extends AI_Agent

singleton Class constructor()
	Super()
	
Function vectorize($value : Variant) : 4D.Vector
	var $result : Object:={}
	
	If ((This.provider="") || (This.model=""))
		throw(999; "Please run setAgent() before running")
		return Null
	End if 
	
	$result:=This.AIClient.embeddings.create($value; This.model)
	return $result.vector