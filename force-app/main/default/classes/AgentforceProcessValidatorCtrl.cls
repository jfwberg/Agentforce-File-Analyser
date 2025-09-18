public with sharing class AgentforceProcessValidatorCtrl {
    
    /** **************************************************************************************************** **
     **                                          PRIVATE CONSTANTS                                           **
     ** **************************************************************************************************** **/
    // Mapping between the model and the related prompt template api name for table extraction
    private final static Map<String,String> LLM_MODEL_TO_PROMPT_TEMPLATE_MAPPING_VALIDATOR     = new Map<String,String>{
        'sfdc_ai__DefaultOpenAIGPT4OmniMini'  => 'Process_Validator',
        'sfdc_ai__DefaultVertexAIGeminiPro25' => 'Process_Validator_Google_Gemini_2_5_Pro'
    };


    @AuraEnabled
    public static Map<String,Object> validateProcess(String modelName, String contentDocumentId, String processJSON){
        try{
            // Define the final prompt template api name
            String promptTemplateName = LLM_MODEL_TO_PROMPT_TEMPLATE_MAPPING_VALIDATOR.get(modelName);

            // Generate input params 
            Map<String, ConnectApi.WrappedValue> inputParams = 
                    new Map<String, ConnectApi.WrappedValue> {
                        'Input:File'         => getWrappedValue(new Map<String,String>{'Id'=>contentDocumentId}),
                        'Input:Process_JSON' => getWrappedValue(processJSON)
                    }
            ;

            // Setup additional configuration items
            ConnectApi.EinsteinLlmAdditionalConfigInput additionalConfigInput = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            additionalConfigInput.applicationName   = 'PromptTemplateGenerationsInvocable';
            additionalConfigInput.enablePiiMasking  = false;
            additionalConfigInput.temperature       = 0.5;

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
                'modelName'             => modelName,
                'promptTemplateName'    => promptTemplateName,
                'processJSON'           => processJSON,
                'llmResponse'           => llmResponse
            };

        }catch (Exception e) {
            throw new AuraHandledException('Error:' + e.getMessage());
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
}