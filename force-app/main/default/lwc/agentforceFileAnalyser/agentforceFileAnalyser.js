/**
 * @date    June 2025
 * @author  Justus van den Berg (jfwberg@gmail.com)
 * @note    This is for demo purposes only
 */
import { track }            from 'lwc';
import { LightningElement } from 'lwc';
import LightningAlert       from 'lightning/alert';

// Apex methods
import analyseFile          from "@salesforce/apex/AgentforceFileAnalyserCtrl.analyseFile";
import deleteFile           from "@salesforce/apex/AgentforceFileAnalyserCtrl.deleteFile";

// Status variables
const STATUS_UPLOAD_COMPLETE         = 'Upload Complete';

// Data cloud action statusses
const STATUS_SEND_TO_LLM             = 'Sending data to LLM';
const STATUS_SEND_TO_LLM_SUCCESS     = 'File Successfully analysed by LLM';
const STATUS_SEND_TO_LLM_ERROR       = 'An error occurred whilst analysing the file by the LLM';

// Document deletion action statusses
const STATUS_DELETE_DOCUMENT         = 'Deleting input file';
const STATUS_DELETE_DOCUMENT_SUCCESS = 'Input File Successfully analysed and deleted';
const STATUS_DELETE_DOCUMENT_ERROR   = 'An error occurred whilst deleting the file. Please delete the uploaded file manually.';

// Main logic
export default class AgentforceFileAnalyser extends LightningElement {

    // Loading indicator for the spinner
    loading = false;

    // LLM picklist
    modelSelected = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
    modelOptions  = [
        { label: 'OpenAI GPT 4 Omni Mini', value: 'sfdc_ai__DefaultOpenAIGPT4OmniMini', default: true },
        { label: 'Google Gemini 2.5 Pro',  value: 'sfdc_ai__DefaultVertexAIGeminiPro25'}
    ];

    // The option to extract tables is disabled by default
    extractTables = false;

    // The question that we can use to ask the user
    question = 'Please give a brief summary of the to analyse file';

    // Document details used for uploading
    @track document = {
        id               : null,
        name             : null,
        status           : null,
        contentBodyId    : null,
        contentVersionId : null
    };

    // LLM Response
    response;

    // Indicator if the response should be shown
    showResponse = false;

    // Some generic data
    category;
    summary;

    // Indicator if any tables have been found
    tablesFound = false;
    
    // Number of tables found
    numberOfTables = 0;

    // Data tables found
    tables      = [];

    // Upload formats
    get acceptedFormats() {
        return ['.png', '.jpg','.pdf'];
    }

    // Disable files after completed upload of when send to LLM
    get fileUploadDisabled(){
        return this.document.status  == STATUS_UPLOAD_COMPLETE ||
                this.document.status == STATUS_SEND_TO_LLM
        ;
    }

    // Disable the question input
    get questionDisabled(){
        return this.fileUploadDisabled || this.extractTables;
    }

    // Indicator if the document table should be visible
    get documentInfoVisible(){
        return this.document.status != null;
    }

    get showLlmResponse(){
        return !this.extractTables;
    }


    /** **************************************************************************************************** **
     **                                        FILE RELATED HANDLERS                                         **
     ** **************************************************************************************************** **/
    handleUploadFinished(event) {
        try{

            // Get the list of uploaded files
            const uploadedFiles = event.detail.files;

            // Update the status
            this.document.status = STATUS_UPLOAD_COMPLETE;

            // Last uploaded document Id
            this.document.id               = uploadedFiles[0].documentId;
            this.document.name             = uploadedFiles[0].name;
            this.document.contentBodyId    = uploadedFiles[0].contentBodyId;
            this.document.contentVersionId = uploadedFiles[0].contentVersionId;

            // Reset values to default
            this.tablesFound    = false;
            this.tables         = [];
            this.showResponse   = false;
            this.category       = null;
            this.summary        = null;
            this.numberOfTables = 0;

            // If the file upload was complete analyse the file
            if(this.document.id){
                this.handleAnalyseFile();
            }
        }catch(error){
            this.handleError(error);
        }
    }


    handleAnalyseFile() {
        try{
            this.loading = true;

            // Update the status
            this.document.status = STATUS_SEND_TO_LLM;

            // Execute Apex
            analyseFile({
                modelName         : this.modelSelected,
                contentDocumentId : this.document.id,
                question          : this.question,
                extractTables     : this.extractTables
            })
            .then((apexResponse) => {
                // Update the status
                this.document.status = STATUS_SEND_TO_LLM_SUCCESS;

                // Update the response
                this.response = apexResponse;

                // Just output the response
                console.log(this.response);

                // Switch flag
                this.showResponse = true;

                try{
                    // Only run the table logic when the tables are extracted                    
                    if(this.extractTables){
                    
                        // Handle the response
                        let responseObject = JSON.parse(apexResponse.llmResponse.trim());
                        let numberOfTables = responseObject.tables.length;

                        // Set the additional data
                        this.category       = responseObject.category;
                        this.summary        = responseObject.summary;

                        // If there is some table data add the tables
                        if(numberOfTables > 0){
                            this.tablesFound    =  true;
                            this.numberOfTables = numberOfTables;
                            this.tables         = responseObject.tables;
                        }
                    }
                }catch(error){
                    this.handleError(error);
                }

                // Delete file
                this.handleDeleteFile();
            })
            .catch((error) => {
                this.handleError(error);
                this.document.status = STATUS_SEND_TO_LLM_ERROR;
                this.handleDeleteFile();
            })
        }catch(error){
            this.handleError(error);
            this.document.status = STATUS_SEND_TO_LLM_ERROR;
            this.handleDeleteFile();
        }
    }


    handleDeleteFile() {
        try{
            // Keep the spinner on
            this.loading = true;

            // Update the status
            this.document.status = STATUS_DELETE_DOCUMENT;

            // Delete the document only if it was uploaded
            if(this.document.id){
                deleteFile({
                        contentDocumentId : this.document.id,
                    })
                    .then(() => {
                        // Update the status
                        this.document.status = STATUS_DELETE_DOCUMENT_SUCCESS;
                    })
                    .catch((error) => {
                        this.handleError(error);
                        this.document.status = STATUS_DELETE_DOCUMENT_ERROR;
                    })
                    .finally(()=>{
                        this.loading = false;
                    }
                );
            }
        }catch(error){
            this.handleError(error);
            this.loading = false;
            this.document.status = STATUS_DELETE_DOCUMENT_ERROR;
        }
    }


    /** **************************************************************************************************** **
     **                                           CHANGE HANDLERS                                            **
     ** **************************************************************************************************** **/
    handleChangeModel(event) {
        this.modelSelected = event.detail.value;
    }

    handleChangeQuestion(event) {
        this.question = event.target.value;
    }

    handleChangeExtractTables(event) {
        if(event.target.checked == true){
            this.question = 'No question asked: File is analysed for Data Tables';
        }else{
            this.question = 'Please give a brief summary of the to analyse file';
        }
        this.extractTables = event.target.checked;
    }


    /** **************************************************************************************************** **
     **                                           SUPPORT METHODS                                            **
     ** **************************************************************************************************** **/
    /**
     * Basic error handling method for both javscript and apex errors
     */
    handleError(error){
        LightningAlert.open({
            message : (error.body) ? error.body.message : error.message,
            label   : 'Error',
            theme   : 'error'
        });
    }
}