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
	Case of 
		: ($formEventCode=On Clicked)
			This.actions.generatingCustomers.running:=1
			This.actions.generatingCustomers.progress:={value: 0; message: "Generating customers"}
			
			OBJECT SET VISIBLE(*; "customerGen@"; True)
			OBJECT SET VISIBLE(*; "btnGenerateCustomers"; False)
			CALL WORKER(String(Session.id)+"-generatingCustomers"; Formula(cs.workerHelper.me.generateCustomers($1; $2)); This; Current form window)
	End case 
	
	
Function btnCustAsyncEventHandler($formEventCode : Integer)
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
			$callbackObject.onData:=This.updateAIText
			$callbackObject.onTerminate:=This.terminateGenerateCustomers
			Form.AIText:=""
			cs.AI_DataGenerator.me.setAgent(This.providersGen.currentValue; This.modelsGen.currentValue)
			cs.AI_DataGenerator.me.generateCustomersAsync(This.actions.generatingCustomers.quantity; This.actions.generatingCustomers.quantityBy; $callbackObject)
			//$customerGenerator.populateAddressesAsync(10; $callbackObject)
			//CALL FORM($window; Formula($formObject.terminateGenerateCustomers()))
			
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
	
Function terminateGenerateCustomers_()
	OBJECT SET VISIBLE(*; "customerGen@"; False)
	OBJECT SET VISIBLE(*; "btnGenerateCustomers"; True)
	
Function terminateGenerateCustomers()
	//EXECUTE METHOD IN SUBFORM("Subform"; This.terminateGenerateCustomers_; *)
	EXECUTE METHOD IN SUBFORM("Subform"; Formula(OBJECT SET VISIBLE(*; "customerGen@"; False)))
	EXECUTE METHOD IN SUBFORM("Subform"; Formula(OBJECT SET VISIBLE(*; "btnGenerateCustomers"; True)))
	
	
	
Function progressGenerateCustomers_($progress : Object)
	Form.actions.generatingCustomers.progress.value:=$progress.value
	Form.actions.generatingCustomers.progress.message:=$progress.message
	
Function progressGenerateCustomers($progress : Object)
	EXECUTE METHOD IN SUBFORM("Subform"; This.progressGenerateCustomers_; *; $progress)
	
Function updateAIText($resultText : Text)
	EXECUTE METHOD IN SUBFORM("Subform"; Formula(Form.AIText+=$1); *; $resultText)
	
	
	//Attempt to scroll down the input area..
	EXECUTE METHOD IN SUBFORM("Subform"; Formula(HIGHLIGHT TEXT(*; "InputAIText"; Length(Form.AIText); Length(Form.AIText))))
	EXECUTE METHOD IN SUBFORM("Subform"; Formula(GOTO OBJECT(*; "InputAIText")))
	
Function terminateAIText($resultText : Text)
	//EXECUTE METHOD IN SUBFORM("Subform"; Formula(Form.AIText+=$1); *; $resultText)
	
	
Function terminateVectorizing_()
	OBJECT SET VISIBLE(*; "embedding@"; False)
	OBJECT SET VISIBLE(*; "btnVectorize"; True)
	
	If (ds.embeddingInfo.embeddingStatus())
		Form.actions.embedding.status:="Done"
		Form.actions.embedding.info:=ds.embeddingInfo.info()
	Else 
		Form.actions.embedding.status:="Missing"
	End if 
	
Function terminateVectorizing()
	EXECUTE METHOD IN SUBFORM("Subform"; This.terminateVectorizing_; *)
	
Function progressVectorizing_($progress : Object)
	Form.actions.embedding.progress.value:=$progress.value
	Form.actions.embedding.progress.message:=$progress.message
	
Function progressVectorizing($progress : Object)
	EXECUTE METHOD IN SUBFORM("Subform"; This.progressVectorizing_; *; $progress)
	
	
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
	
	
	
	