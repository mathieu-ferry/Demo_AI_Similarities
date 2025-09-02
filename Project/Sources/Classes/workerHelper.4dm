singleton Class constructor()
	
	
/**
* Vectorize
**/
Function vectorizeCustomers($formObject : Object; $window : Integer)
	ds.customer.vectorizeAll($formObject.providersEmb.currentValue; $formObject.modelsEmb.currentValue; {window: $window; formula: Formula($formObject.progressVectorizing($1))})
	CALL FORM($window; Formula($formObject.terminateVectorizing()))
	
	
/**
* Search similar customers for a customer (as object)
**/
	
Function searchSimilarCustomers($formObject : Object; $customerObject : Object; $window : Integer)
	var $startMillisecond; $timing : Integer
	var $customer : cs.customerEntity
	var $similarCustomers : Collection
	
	$customer:=ds.customer.newCustomerFromObject($customerObject)
	$startMillisecond:=Milliseconds
	$similarCustomers:=$customer.searchSimilarCustomers($formObject.actions.searchingSimilarities.similarityLevel/100)
	$timing:=Milliseconds-$startMillisecond
	
	CALL FORM($window; Formula($formObject.terminateSearchSimilarCustomers($similarCustomers; $timing)))
	
	
/**
* List similar customers for all customers
**/
Function searchAllSimilarCustomers($formObject : Object; $window : Integer)
	var $startMillisecond; $timing : Integer
	var $customersWithSimilarities : Collection
	
	$startMillisecond:=Milliseconds
	$customersWithSimilarities:=ds.customer.customersWithSimilarities($formObject.actions.searchingSimilarities.similarityLevel/100)
	$timing:=Milliseconds-$startMillisecond
	CALL FORM($window; Formula($formObject.terminateSearchAllSimilarCustomers($customersWithSimilarities; $timing)))