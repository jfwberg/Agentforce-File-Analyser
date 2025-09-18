public with sharing class AgentforceProcessQuestionCtrl {

    /** **************************************************************************************************** **
     **                                          PRIVATE CONSTANTS                                           **
     ** **************************************************************************************************** **/
    // Mapping between the model and the related prompt template api name for questions
    private final static Map<String,String> LLM_MODEL_TO_PROMPT_TEMPLATE_MAPPING_QUESTION = new Map<String,String>{
        'sfdc_ai__DefaultOpenAIGPT4OmniMini'  => 'Process_Question',
        'sfdc_ai__DefaultVertexAIGeminiPro25' => 'Process_Question_Google_Gemini_2_5_Pro'
    };

   


    /** **************************************************************************************************** **
     **                                        AURA ENABLED METHODS                                          **
     ** **************************************************************************************************** **/
    @AuraEnabled
    public static Map<String,Object> ask(String modelName, String recordId, String question){
        try{
            // Define the final prompt template api name
            String promptTemplateName = LLM_MODEL_TO_PROMPT_TEMPLATE_MAPPING_QUESTION.get(modelName);

            //(Process__c)[SELECT Id FROM Process__c WHERE Id=:recordId WITH SYSTEM_MODE LIMIT 1]

            // Generate input params 
            Map<String, ConnectApi.WrappedValue> inputParams = 
                new Map<String, ConnectApi.WrappedValue> {
                    'Input:Process'	     => getWrappedValue(new Map<String,Object>{'Id'=>recordId}),
                    'Input:Question'     => getWrappedValue(question),
                    'Input:Process_JSON' => getWrappedValue(getLatestProcessFileBodyViaDoc(recordId,'Agentforce Process Analyser Json').toString())
                }
            ;

            // Setup additional configuration items
            ConnectApi.EinsteinLlmAdditionalConfigInput additionalConfigInput = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            additionalConfigInput.applicationName   = 'PromptTemplateGenerationsInvocable';
            additionalConfigInput.enablePiiMasking  = false;
            additionalConfigInput.temperature 		= 0.5;

            // Setup all inputs for the prompts            
            ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            executeTemplateInput.additionalConfig   = additionalConfigInput;
            executeTemplateInput.isPreview          = false;
            executeTemplateInput.citationMode       = 'off';
            executeTemplateInput.inputParams        = inputParams;

            // Call LLM and generate response
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = (Test.isRunningTest()) ? null : ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                promptTemplateName,
                executeTemplateInput
            );

            // Extract the JSON response
            String llmResponse = (Test.isRunningTest()) ? null : generationsOutput.generations[0]?.text?.removeStart('```json')?.removeEnd('```')?.trim();

            // Return the LLM response
            return new Map<String,Object>{
                'modelName'          => modelName,
                'promptTemplateName' => promptTemplateName,
                'question'           => question,
                'llmResponse'        => llmResponse
            };

        }catch (Exception e) {   
          throw new AuraHandledException(e.getMessage());
        }
    }


    /** **************************************************************************************************** **
     **                                      PRIVATE SUPPORT METHODS                                         **
     ** **************************************************************************************************** **/
    /**
     * @description Method to make it slightly easier to add wrapped values
     * @return      ConnectApi.WrappedValue  ready value
     */
    private static ConnectApi.WrappedValue getWrappedValue(Object input){
        ConnectApi.WrappedValue wrappedValue = new ConnectApi.WrappedValue();
        wrappedValue.value = input;
        return wrappedValue;
    }

    public static Blob getLatestProcessFileBodyViaDoc(String processId, String title) {
        
        ContentDocumentLink link = [
            SELECT ContentDocumentId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :processId
            AND ContentDocument.Title = :title
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];
        ContentVersion cv = [
            SELECT Id, VersionData
            FROM ContentVersion
            WHERE Id = :link.ContentDocument.LatestPublishedVersionId
            LIMIT 1
        ];
        
        return cv.VersionData; 
        
    }
}