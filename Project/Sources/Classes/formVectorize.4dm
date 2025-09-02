property providersEmb : Object
property modelsEmb : Object
property providersGen : Object
property modelsGen : Object
property actions : Object
property AIText : Text

Class constructor()
	var $providers : cs.providerSettingsSelection
	var $provider : cs.providerSettingsEntity
	var $models : Collection
	
	This.AIText:=""
	This.providersEmb:={values: []; index: 0}
	This.modelsEmb:={values: []; index: 0}
	This.providersGen:={values: []; index: 0}
	This.modelsGen:={values: []; index: 0}
	
	$providers:=ds.providerSettings.providersAvailable("embedding")
	If ($providers.length>0)
		This.providersEmb.values:=$providers.extract("name")
		$provider:=$providers.first()
		$models:=$provider.embeddingModels.models
		This.modelsEmb.values:=$models.extract("model")
		This.modelsEmb.index:=This.modelsEmb.values.findIndex(Formula($1.value=$provider.defaults.embedding))
	End if 
	
	$providers:=ds.providerSettings.providersAvailable("reasonning")
	If ($providers.length>0)
		This.providersGen.values:=$providers.extract("name")
		$provider:=$providers.first()
		$models:=$provider.reasonningModels.models
		This.modelsGen.values:=$models.extract("model")
		This.modelsGen.index:=This.modelsGen.values.findIndex(Formula($1.value=$provider.defaults.reasonning))
	End if 
	
	This.actions:={\
		embedding: {running: 0; progress: {value: 0; message: ""}}; \
		generatingCustomers: {running: 0; progress: {value: 0; message: ""}; quantity: 30; quantityBy: 10}\
		}
	
	If (ds.embeddingInfo.embeddingStatus())
		This.actions.embedding.status:="Done"
		This.actions.embedding.info:=ds.embeddingInfo.info()
	Else 
		This.actions.embedding.status:="Missing"
	End if 
	
	
	//MARK: -
	//MARK: Form & form objects event handlers
	
Function formEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Load)
			OBJECT SET VISIBLE(*; "customerGen@"; False)
			OBJECT SET VISIBLE(*; "embedding@"; False)
	End case 
	
Function providersGenListEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Data Change)
			This.modelsGen:=This.setModelList(This.providersGen; "reasonning")
	End case 
	
Function providersEmbListEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Data Change)
			This.modelsEmb:=This.setModelList(This.providersEmb; "embedding")
	End case 
	
	
Function btnGenerateCustomersEventHandler($formEventCode : Integer)
	var $customerGenerator : cs.AI_DataGenerator
	var $formulaCallback : 4D.Function
	var $callbackObject : Object
	
	Case of 
		: ($formEventCode=On Clicked)
			This.actions.generatingCustomers.running:=1
			This.actions.generatingCustomers.progress:={value: 0; message: "Generating customers"}
			
			OBJECT SET VISIBLE(*; "customerGen@"; True)
			OBJECT SET VISIBLE(*; "btnGenerateCustomers"; False)
			
			$callbackObject:={}
			$callbackObject.onProgress:=This.progressGenerateCustomers
			$callbackObject.onTerminate:=This.terminateGenerateCustomers
			Form.AIText:=""
			cs.AI_CustomersGenerator.me.setAgent(This.providersGen.currentValue; This.modelsGen.currentValue)
			cs.AI_CustomersGenerator.me.generateCustomersAsync(This.actions.generatingCustomers.quantity; This.actions.generatingCustomers.quantityBy; $callbackObject)
			
	End case 
	
	
Function btnVectorizeEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This.actions.embedding.running:=1
			This.actions.embedding.status:="In progress"
			This.actions.embedding.embeddingInfo:=ds.embeddingInfo.dummyInfo()
			This.actions.embedding.progress:={value: 0; message: "Generating embeddings"}
			
			OBJECT SET VISIBLE(*; "embedding@"; True)
			OBJECT SET VISIBLE(*; "btnVectorize"; False)
			CALL WORKER(String(Session.id)+"-embedding"; Formula(cs.workerHelper.me.vectorizeCustomers($1; $2)); This; Current form window)
	End case 
	
Function btnDropDataEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			ds.customer.all().drop()
			ds.embeddingInfo.all().drop()
			This.actions.embedding:={running: 0; progress: {value: 0; message: ""}; status: "Missing"}
	End case 
	
	
	//MARK: -
	//MARK: Form actions callback functions
	
Function terminateGenerateCustomers()
	If (Current form name="menu")
		EXECUTE METHOD IN SUBFORM("Subform"; Formula(Form.terminateGenerateCustomers()); *)
	Else 
		OBJECT SET VISIBLE(*; "customerGen@"; False)
		OBJECT SET VISIBLE(*; "btnGenerateCustomers"; True)
	End if 
	
Function progressGenerateCustomers($resultText : Text; $progress : Object)
	If (Current form name="menu")
		EXECUTE METHOD IN SUBFORM("Subform"; Formula(Form.progressGenerateCustomers($1; $2)); *; $resultText; $progress)
	Else 
		Form.AIText+=$resultText
		If ($progress#Null)
			Form.actions.generatingCustomers.progress.value:=$progress.value
			Form.actions.generatingCustomers.progress.message:=$progress.message
		End if 
		//scroll down
		HIGHLIGHT TEXT(*; "InputAIText"; Length(Form.AIText); Length(Form.AIText))
		GOTO OBJECT(*; "InputAIText")
	End if 
	
Function terminateVectorizing()
	If (Current form name="menu")
		EXECUTE METHOD IN SUBFORM("Subform"; Formula(Form.terminateVectorizing()); *)
	Else 
		OBJECT SET VISIBLE(*; "embedding@"; False)
		OBJECT SET VISIBLE(*; "btnVectorize"; True)
		
		If (ds.embeddingInfo.embeddingStatus())
			Form.actions.embedding.status:="Done"
			Form.actions.embedding.info:=ds.embeddingInfo.info()
		Else 
			Form.actions.embedding.status:="Missing"
		End if 
	End if 
	
Function progressVectorizing($progress : Object)
	If (Current form name="menu")
		EXECUTE METHOD IN SUBFORM("Subform"; Formula(Form.progressVectorizing($1)); *; $progress)
	Else 
		Form.actions.embedding.progress.value:=$progress.value
		Form.actions.embedding.progress.message:=$progress.message
	End if 
	
	
	//MARK: -
	//MARK: Other functions
	
Function setModelList($providerList : Object; $kind : Text) : Object
	var $provider : cs.providerSettingsEntity
	var $models : Collection
	var $list : Object:={}
	var $defaultModel : Text
	
	$provider:=ds.providerSettings.query("name = :1"; $providerList.currentValue).first()
	Case of 
		: ($kind="reasonning")
			$models:=$provider.reasonningModels.models
			$defaultModel:=$provider.defaults.reasonning
		: ($kind="embedding")
			$models:=$provider.embeddingModels.models
			$defaultModel:=$provider.defaults.embedding
	End case 
	$list.values:=$models.extract("model")
	$list.index:=$list.values.findIndex(Formula($1.value=$defaultModel))
	
	return $list
	
	//MARK: -
	//MARK: Computed properties
	
Function get embeddingDateTime() : Text
	return String(This.actions.embedding.info.embeddingDate; "dd/MM/yyyy")+" "+String(Time(This.actions.embedding.info.embeddingTime); "HH:mm:ss")
	
	
	
	