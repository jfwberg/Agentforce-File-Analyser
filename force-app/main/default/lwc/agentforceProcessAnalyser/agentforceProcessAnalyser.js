/**
 * @date    June 2025
 * @author  Justus van den Berg (jfwberg@gmail.com)
 * @note    This is for demo purposes only
 */
import { track }            from 'lwc';
import { LightningElement } from 'lwc';
import LightningAlert       from 'lightning/alert';

// Apex methods
import extractProcess       from "@salesforce/apex/AgentforceProcessExtractorCtrl.extractProcess";
import validateProcess      from "@salesforce/apex/AgentforceProcessValidatorCtrl.validateProcess";
import deleteFile           from "@salesforce/apex/AgentforceFileAnalyserCtrl.deleteFile";
import fixProcess           from "@salesforce/apex/AgentforceProcessFixerCtrl.fixProcess";
import createProcessRecords from "@salesforce/apex/AgentforceProcessRecordCreatorCtrl.createProcessRecords";

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
export default class AgentforceProcessAnalyser extends LightningElement {

    // Loading indicator for the spinner
    loading = false;

    // LLM picklist
    modelSelected = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
    modelOptions  = [
        { label: 'OpenAI GPT 4 Omni Mini', value: 'sfdc_ai__DefaultOpenAIGPT4OmniMini', default: true },
        { label: 'Google Gemini 2.5 Pro',  value: 'sfdc_ai__DefaultVertexAIGeminiPro25'}
    ];


    // The additional instructions that a user can provide
    additionalInstructions = '';

    // Document details used for uploading
    @track document = {
        id               : null,
        name             : null,
        status           : null,
        contentBodyId    : null,
        contentVersionId : null
    };

    // LLM Response
    @track response;
    @track validationResponse;

    // Indicator if the response should be shown
    showResponse           = false;
    showValidationResponse = false;

    // Upload formats
    get acceptedFormats() {
        return ['.png', '.jpg','.pdf','.svg','.txt','.xml','.visio'];
    }

    // Disable files after completed upload of when send to LLM
    get fileUploadDisabled(){
        return this.document.status  == STATUS_UPLOAD_COMPLETE ||
                this.document.status == STATUS_SEND_TO_LLM
        ;
    }

    // Indicator if the document table should be visible
    get documentInfoVisible(){
        return this.document.status != null;
    }

   

    get validationResponseText(){
        return this.simpleMdToHtml(this.validationResponse.llmResponse);
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
            extractProcess({
                modelName               : this.modelSelected,
                contentDocumentId       : this.document.id,
                additionalInstructions  : this.additionalInstructions
            })
            .then((apexResponse) => {
                // Update the status
                this.document.status = STATUS_SEND_TO_LLM_SUCCESS;

                // Update the response
                this.response = apexResponse;

                // Just output the response
                console.log('response', this.response);

                // Switch flag
                this.showResponse = true;

                // Remove the loading screen
                this.loading = false;

                // Delete file
                //this.handleDeleteFile();
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


    handleValidateProcess() {
        try{
            this.loading = true;

            // Update the status
            this.document.status = STATUS_SEND_TO_LLM;

            // Execute Apex
            validateProcess({
                modelName           : this.modelSelected,
                contentDocumentId   : this.document.id,
                processJSON         : this.response.llmResponse
            })
            .then((apexResponse) => {
                 
                // Update the status
                this.document.status = STATUS_SEND_TO_LLM_SUCCESS;

                // Update the response
                this.validationResponse = apexResponse;

                // Switch flag
                this.showValidationResponse = true;

                // Remove the loading screen
                this.loading = false;

                // Delete file
                // this.handleDeleteFile();
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

    handleFixProcess() {
        try{
            this.loading = true;

            // Update the status
            this.document.status = STATUS_SEND_TO_LLM;

            this.showResponse           = false;
            this.showValidationResponse = false;

            // Execute Apex
            fixProcess({
                modelName           : this.modelSelected,
                contentDocumentId   : this.document.id,
                processJSON         : this.response.llmResponse,
                validationResult    : this.validationResponse.llmResponse
            })
            .then((apexResponse) => {

                // Update the response
                this.response = apexResponse;


                this.showResponse    = true;

                // Remove the loading screen
                this.loading = false;

                // Delete file
                //this.handleDeleteFile();
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


    handleCreateProcessRecords() {
        try{
            this.loading = true;

            // Execute Apex
            createProcessRecords({
                jsonString       : this.response.llmResponse,
                validationResult : this.validationResponse.llmResponse,
                modelName        : this.modelSelected,
                contentDocumentId: this.document.id
            })
            .then((apexResponse) => {
                if(apexResponse == true){
                    
                    LightningAlert.open({
                        message : 'Successfully created process records',
                        label   : 'Success',
                        theme   : 'succes'
                    });

                    // Delete file
                    // this.handleDeleteFile();
                }

                this.loading = false;
            })
            .catch((error) => {
                this.handleError(error);
            })
            .finally(()=>{
                this.loading = false;
            })
        }catch(error){
            this.handleError(error);
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

    handleChangeAdditionalInstructions(event) {
        this.additionalInstructions = event.target.value;
    
    }
    handleChangeLlmResponse(event) {
        this.response.llmResponse = event.target.value;
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


    /**
     * Basic markdown converter thank chatGPT :)
     */
    simpleMdToHtml(md) {
        // Normalize: turn " * " bullets and CRLF into neat lines
        let text = (md || '').replace(/\r\n?/g, '\n').replace(/\s\*\s/g, '\n* ');

        // Escape HTML to prevent injection
        text = text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');

        // Inline code: `like this`
        text = text.replace(/`([^`]+)`/g, '<code>$1</code>');

        // Build paragraphs and <ul>/<li>
        const lines = text.split('\n');
        const out = [];
        let inList = false;

        for (const line of lines) {
        if (/^\s*\*\s+/.test(line)) {
            if (!inList) { out.push('<ul>'); inList = true; }
            out.push('<li>' + line.replace(/^\s*\*\s+/, '') + '</li>');
        } else if (line.trim()) {
            if (inList) { out.push('</ul>'); inList = false; }
            out.push('<p>' + line + '</p>');
        }
        }
        if (inList) out.push('</ul>');

        return out.join('');
    }

}