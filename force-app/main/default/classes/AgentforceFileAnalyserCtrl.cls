public with sharing class AgentforceFileAnalyserCtrl {

    /** **************************************************************************************************** **
     **                                          PRIVATE CONSTANTS                                           **
     ** **************************************************************************************************** **/
    // Mapping between the model and the related prompt template api name for questions
    private final static Map<String,String> LLM_MODEL_TO_PROMPT_TEMPLATE_MAPPING_QUESTION = new Map<String,String>{
        'sfdc_ai__DefaultOpenAIGPT4OmniMini'  => 'File_Analyser',
        'sfdc_ai__DefaultVertexAIGeminiPro25' => 'File_Analyser_Google_Gemini_2_5_Pro'
    };

    // Mapping between the model and the related prompt template api name for table extraction
    private final static Map<String,String> LLM_MODEL_TO_PROMPT_TEMPLATE_MAPPING_TABLE     = new Map<String,String>{
        'sfdc_ai__DefaultOpenAIGPT4OmniMini'  => 'Table_Extractor',
        'sfdc_ai__DefaultVertexAIGeminiPro25' => 'Table_Extractor_Google_Gemini_2_5_Pro'
    };


    /** **************************************************************************************************** **
     **                                        AURA ENABLED METHODS                                          **
     ** **************************************************************************************************** **/
    @AuraEnabled
    public static Map<String,Object> analyseFile(String modelName, String contentDocumentId, String question, Boolean extractTables){
        try{
            // Define the final prompt template api name
            String promptTemplateName = (extractTables ? 
                LLM_MODEL_TO_PROMPT_TEMPLATE_MAPPING_TABLE : 
                LLM_MODEL_TO_PROMPT_TEMPLATE_MAPPING_QUESTION
            ).get(modelName);

            // Generate input params 
            Map<String, ConnectApi.WrappedValue> inputParams = 
                extractTables ?
                    new Map<String, ConnectApi.WrappedValue>{
                        'Input:File'	 => getWrappedValue(new Map<String,String>{'Id'=>contentDocumentId})
                    } :
                    new Map<String, ConnectApi.WrappedValue>{
                        'Input:File'	 => getWrappedValue(new Map<String,String>{'Id'=>contentDocumentId}),
                        'Input:Question' => getWrappedValue(question)
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
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                promptTemplateName,
                executeTemplateInput
            );

            // Extract the JSON response
            String llmResponse = generationsOutput.generations[0]?.text?.removeStart('```json')?.removeEnd('```')?.trim();

            // Return the LLM response
            return new Map<String,Object>{
                'modelName'          => modelName,
                'promptTemplateName' => promptTemplateName,
                'question'           => question,
                'extractTables'      => extractTables,
                'llmResponse'        => llmResponse
            };

        }catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


    @AuraEnabled
    public static Boolean deleteFile(String contentDocumentId){
        try{            
            // Delete the uploaded document (finally doesnt work well with AuraHandled Exceptions)
            delete as user [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId LIMIT 1];
            
            // return true when all is good
            return true;

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
}