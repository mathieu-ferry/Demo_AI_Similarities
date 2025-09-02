Class extends DataClass

Function vectorizeAll($provider : Text; $model : Text; $callback : Object)
	var $customer : cs.customerEntity
	var $embeddingInfo : cs.embeddingInfoEntity
	var $startTime : Integer:=Milliseconds
	var $endTime : Integer
	var $total; $generated : Integer
	var $progress : Object:={}
	
	$total:=This.all().length
	$generated:=0
	
	For each ($customer; This.all())
		$customer.vectorize($provider; $model; True)
		$customer.save()
		
		If ($callback#Null)
			$generated+=1
			$progress.value:=Int($generated/$total*100)
			$progress.message:="Generating embeddings "+String($generated)+"/"+String($total)
			CALL FORM($callback.window; $callback.formula; $progress)
		End if 
		
	End for each 
	
	$endTime:=Milliseconds
	
	$embeddingInfo:=ds.embeddingInfo.info()
	$embeddingInfo.provider:=$provider
	$embeddingInfo.model:=$model
	$embeddingInfo.embeddingDate:=Current date
	$embeddingInfo.embeddingTime:=Current time
	$embeddingInfo.duration:=$endTime-$startTime
	
	$embeddingInfo.save()
	
	
Function pushCustomerSimilarity($customersCol : Collection; $customerX : cs.customerEntity; $customerY : cs.customerEntity; $similarity : Real) : Collection
/**
* $customerX similarity with $customerY is the same than
* $customerY similarity with $customerY
**/
	var $objCustomer : Object
	
	If ($customersCol.query("entity.ID = :1"; $customerX.ID).length=0)
		$customersCol.push({entity: $customerX; customerID: $customerX.ID; similarities: []})
	End if 
	$objCustomer:=$customersCol.query("entity.ID = :1"; $customerX.ID).first()
	$objCustomer.similarities.push({entity: $customerY; customerID: $customerY.ID; similarity: $similarity})
	
	If ($customersCol.query("entity.ID = :1"; $customerY.ID).length=0)
		$customersCol.push({entity: $customerY; customerID: $customerY.ID; similarities: []})
	End if 
	$objCustomer:=$customersCol.query("entity.ID = :1"; $customerY.ID).first()
	$objCustomer.similarities.push({entity: $customerX; customerID: $customerX.ID; similarity: $similarity})
	
	return $customersCol
	
Function customersWithSimilarities($targetSimilarity : Real) : Collection
	var $customersCol : Collection:=[]
	var $customerX; $customerY : cs.customerEntity
	var $customersX; $customersY : cs.customerSelection
	var $similarities : Integer
	var $similarity : Real
	var $objCustomer : Object
	
	
	If (ds.embeddingInfo.embeddingStatus()=False)
		throw(999; "Cannot find similarities, no embedding info found. Please generate embeddings")
		return []
	End if 
	
	$customersX:=ds.customer.all().orderBy("ID")
	
	For each ($customerX; $customersX)
		If ($customerX.vector#Null)
			$customersY:=$customersX.slice($customerX.indexOf()+1)
			For each ($customerY; $customersY)
				If ($customerY.vector#Null)
					$similarity:=$customerX.vector.cosineSimilarity($customerY.vector)
					If ($similarity>=$targetSimilarity)
						$customersCol:=This.pushCustomerSimilarity($customersCol; $customerX; $customerY; $similarity)
					End if 
				End if 
				
			End for each 
		End if 
		
	End for each 
	
	For each ($objCustomer; $customersCol)
		$objCustomer.similarities:=$objCustomer.similarities.orderBy("similarity desc")
		$objCustomer.bestMatch:=$objCustomer.similarities.first().similarity
	End for each 
	$customersCol:=$customersCol.orderBy("bestMatch desc")
	return $customersCol
	
Function newCustomerFromObject($customerObject : Object) : cs.customerEntity
	var $customer : cs.customerEntity
	var $addressObj : Object
	
	$customer:=ds.customer.new()
	$addressObj:=$customerObject.address
	OB REMOVE($customerObject; "address")
	$customer.fromObject($customerObject)
	$customer.address:=cs.address.new($addressObj)
	return $customer
	
	
	
	
	