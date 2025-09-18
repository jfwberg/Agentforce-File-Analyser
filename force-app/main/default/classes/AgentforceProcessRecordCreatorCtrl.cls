public with sharing class AgentforceProcessRecordCreatorCtrl {
    
    @AuraEnabled
    public static Boolean createProcessRecords(String jsonString, String validationResult, String modelName, String contentDocumentId){
        try {
            // Lists of records to create
            Process__c[] processRecords = new Process__c[]{};
            Step__c[]    stepRecords    = new Step__c   []{};
            Outcome__c[] outcomeRecords = new Outcome__c[]{};

            // Mapping between proccess object ids and Salesforce ids
            Map<String,String>             processIdToSfdcIdMap = new Map<String,String>();
            Map<String,Map<String,String>> stepIdToSfdcIdMap    = new Map<String,Map<String,String>>();

            // ChatGPT adds all these unicode characters that break everyting, so remove them just in case
            jsonString = jsonString.replaceAll('[\\p{Cntrl}\\p{Z}&&[^\\u0020]]', '');

            // Step 01, validate the JSON is OK
            String[] validationErrors = AgentforceProcess.validateJson(jsonString);

            // If there are any errors throw them combined with a return
            if(!validationErrors.isEmpty()){
                throw new StringException(String.join(validationErrors, '\n'));
            }

            // Parse the processes
            AgentforceProcess.Process[] processes = AgentforceProcess.parse(jsonString);

            // Iterate the processes
            for(AgentforceProcess.Process process : processes){

                // Create the proces Id mapping for this process
                stepIdToSfdcIdMap.put(process.processId,new Map<String,String>());

                // Create a new process record
                processRecords.add(
                    new Process__c(
                        Name                 = process.processName,
                        Id__c                = process.processId,
                        Version__c           = process.processVersion,
                        Description__c       = process.processDescription,
                        Start_Step_Id__c     = process.startStepId,
                        Notes__c             = String.join(process.notes,'\n'),
                        Validation_Result__c = validationResult,
                        AI_Model__c          = modelName,
                        Summary__c           = process.processSummary
                    )
                );

                // Iterate the process steps
                for(AgentforceProcess.Step step : process.processSteps){

                    stepRecords.add(
                        new Step__c(
                            Id__c           = step.stepId,
                            Actor__c        = step.actor,
                            Actor_Role__c   = step.actorRole,
                            Action__c       = step.action,
                            Type__c         = step.type,
                            Next_Step_Id__c = step.nextStepId,
                            Process_Id__c   = process.processId
                        )
                    );

                    // Iterate the outcomes
                    for(AgentforceProcess.Outcome outcome : step.outcomes ?? new AgentforceProcess.Outcome[]{}){
                        outcomeRecords.add(
                            new Outcome__c(
                                Step_Id__c      = step.stepId,
                                Condition__c    = outcome.condition,
                                Next_Step_Id__c = outcome.nextStepId,
                                Process_Id__c   = process.processId
                            )
                        );
                    }
                }
            }

            // Insert all the records
            insert as system processRecords;
            insert as system stepRecords;
            insert as system outcomeRecords;

            // Create mapping between Process Id and Salesforce Id
            for(Process__c processRecord : processRecords){
                processIdToSfdcIdMap.put(processRecord.Id__c, processRecord.Id);
            }

            // Create mapping between Step Id and Salesforce Id
            for(Step__c stepRecord : stepRecords){
                stepIdToSfdcIdMap.get(stepRecord.Process_Id__c).put(stepRecord.Id__c, stepRecord.Id);
            }

            // Populate the lookups for the process and the next step fields
            for(Step__c stepRecord : stepRecords){
                stepRecord.Process__c   = processIdToSfdcIdMap.get(stepRecord.Process_Id__c);
                stepRecord.Next_Step__c = stepIdToSfdcIdMap.get(stepRecord.Process_Id__c)?.get(stepRecord.Next_Step_Id__c);
            }
            update as system stepRecords;

            // Populate the lookups for the step, next step and process fields
            for(Outcome__c outcomeRecord : outcomeRecords){
                outcomeRecord.Step__c      = stepIdToSfdcIdMap.get(outcomeRecord.Process_Id__c).get(outcomeRecord.Step_Id__c);
                outcomeRecord.Next_Step__c = stepIdToSfdcIdMap.get(outcomeRecord.Process_Id__c).get(outcomeRecord.Next_Step_Id__c);
                outcomeRecord.Process__c   = processIdToSfdcIdMap.get(outcomeRecord.Process_Id__c);
            }
            update as system outcomeRecords;

            // Populate the lookup for the start step field
            for(Process__c processRecord : processRecords){
                processRecord.Start_Step__c = stepIdToSfdcIdMap.get(processRecord.Id__c).get(processRecord.Start_Step_Id__c);
            }
            update as system processRecords;

            // Content document
            ContentDocumentLink[] cdls = new ContentDocumentLink[]{};

            // Create a file for each process with the full process results
            for(Integer i =0,max=processRecords.size();i<max;i++){
            
                // Create the file for the specific process containing the JSON
                createContentDocument(
                    processRecords[i].Id, 
                    Blob.valueOf(JSON.serializePretty(processes[i]))
                );

                // Link the uploaded file
                if(!String.isBlank(contentDocumentId)){
                    cdls.add(
                        new ContentDocumentLink(
                            ContentDocumentId = contentDocumentId,
                            LinkedEntityId = processRecords[i].Id,
                            ShareType = 'V'
                        )
                    );
                }
            }

            // Insert the document link to the uploaded file
            insert as system cdls;

            // If no errors just return true
            return true;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


    /**
     * @description Very inefficient way to add a file for each process but it's a demo :-)
     */
    private static void createContentDocument(String recordId, Blob versionData) {
        
        // Create a new ContentVersion
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.VersionData    = versionData;
        contentVersion.Title          = 'Agentforce Process Analyser Json';
        contentVersion.PathOnClient   = recordId + '_Agentforce_Process_Analyser.json';
        insert as system contentVersion;
        
        String contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:contentVersion.Id LIMIT 1]?.ContentDocumentId;

        ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
        contentDocumentLink.ContentDocumentId = contentDocumentId;
        contentDocumentLink.LinkedEntityId = recordId;
        contentDocumentLink.ShareType = 'I'; // 'V' for Viewer access
        insert as system contentDocumentLink;
    }
}