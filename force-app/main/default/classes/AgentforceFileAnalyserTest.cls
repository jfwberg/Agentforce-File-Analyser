/**
 * @author      Justus van den Berg (jfwberg@gmail.com)
 * @date        September 2025
 * @description A test class for coverage only so that we can create a package
 * @note        This is not a production type package but a POC so I dont want to waste my time
 *              writing complex test classes when not required. So coverage for packaging puroses only
 */
@IsTest
private with sharing class AgentforceFileAnalyserTest {
    
    @IsTest
    static void coverageOnly(){
     
        
        AgentforceFileAnalyserCtrl.analyseFile('sfdc_ai__DefaultOpenAIGPT4OmniMini','null','',false);
        AgentforceFileAnalyserCtrl.analyseFile('sfdc_ai__DefaultOpenAIGPT4OmniMini','null','',true);
        AgentforceTableExtractorCtrl.extractTable('sfdc_ai__DefaultOpenAIGPT4OmniMini','null','',false);
        AgentforceTableExtractorCtrl.extractTable('sfdc_ai__DefaultOpenAIGPT4OmniMini','null','',true);
        AgentforceProcessExtractorCtrl.extractProcess('sfdc_ai__DefaultOpenAIGPT4OmniMini','null','null');
        AgentforceProcessValidatorCtrl.validateProcess('sfdc_ai__DefaultOpenAIGPT4OmniMini','null','null');
        

        // Create a new ContentVersion
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.VersionData    = Blob.valueOf('Data');
        contentVersion.Title          = 'Input Diagram';
        contentVersion.PathOnClient   = 'Input_Diagram.json';
        insert as system contentVersion;
        
        String contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:contentVersion.Id LIMIT 1]?.ContentDocumentId;

        // Create records
        String jsonString = '[ { "processId": "PROC_0001", "processName": "Chell Test Chamber Procedure", "processDescription": "A process flow outlining the steps Chell takes upon entering a test chamber, including safety checks and various test courses.", "processVersion": "1.0", "startStepId": "PS_001", "actorRoles": [ "Human", "System" ], "tags": [ "Test Chamber", "Portal" ], "processSteps": [ { "stepId": "PS_001", "actor": "Chell", "actorRole": "Human", "action": "Chell enters Test Chamber", "type": "Process", "nextStepId": "PS_002" }, { "stepId": "PS_002", "actor": "System", "actorRole": "System", "action": "Safety waiver signed?", "type": "Decision", "outcomes": [ { "condition": "Yes", "nextStepId": "PS_003" }, { "condition": "No", "nextStepId": "PS_004" } ] }, { "stepId": "PS_003", "actor": "Human", "actorRole": "Human", "action": "Calibrate Aperture Science Handheld Portal Device", "type": "Process", "nextStepId": "PS_005" }, { "stepId": "PS_004", "actor": "GLADOS AI", "actorRole": "System", "action": "GLADOS requests signature", "type": "Process", "nextStepId": "PS_005" }, { "stepId": "PS_005", "actor": "System", "actorRole": "System", "action": "GLADOS mood stable?", "type": "Decision", "outcomes": [ { "condition": "Yes", "nextStepId": "PS_006" }, { "condition": "No/Timout", "nextStepId": "PS_007" } ] }, { "stepId": "PS_006", "actor": "System", "actorRole": "System", "action": "END", "type": "End", "endState": "cancelled" }, { "stepId": "PS_007", "actor": "Turret Robot", "actorRole": "System", "action": "Turret live-fire course", "type": "Process", "nextStepId": "PS_008" }, { "stepId": "PS_008", "actor": "System", "actorRole": "System", "action": "Override succeeded?", "type": "Decision", "outcomes": [ { "condition": "Yes", "nextStepId": "PS_009" }, { "condition": "Yes", "nextStepId": "PS_010" } ] }, { "stepId": "PS_009", "actor": "System", "actorRole": "System", "action": "END", "type": "End", "endState": "failure" }, { "stepId": "PS_010", "actor": "System", "actorRole": "System", "action": "Subject survives course?", "type": "Process", "nextStepId": "PS_011" }, { "stepId": "PS_011", "actor": "System", "actorRole": "System", "action": "END", "type": "End" } ], "notes": [ "The flowchart contains several ambiguities and invalid structures.", "Step \'GLADOS requests signature\' (PS_004) is a terminal step with no explicit end node; its nextStepId is set to null.", "Step \'Turret live-fire course\' (PS_007) has an ambiguous second path to an \'END (failure)\' node which was ignored in favor of the main downward flow.", "Decision \'Override succeeded?\' (PS_008) is invalid as it has two \'Yes\' outcomes leading to different paths (PS_009 and PS_010). Both have been included as per the diagram.", "Step \'Subject survives course?\' (PS_010) is phrased as a question but depicted as a process block. It also has an ambiguous second path to an \'END (failure)\' node which was ignored in favor of the main downward flow to step PS_011." ] } ]';
        AgentforceProcessRecordCreatorCtrl.createProcessRecords(jsonString, 'All Good!','',contentDocumentId);

        String processId = [SELECT Id FROM Process__c LIMIT 1]?.Id;
        
        

        AgentforceProcessQuestionCtrl.ask(
            'sfdc_ai__DefaultOpenAIGPT4OmniMini',
            processId,
            'What?!'
        );


        AgentforceFileAnalyserCtrl.deleteFile(processId);
        AgentforceTableExtractorCtrl.deleteFile(contentDocumentId);

    }
}