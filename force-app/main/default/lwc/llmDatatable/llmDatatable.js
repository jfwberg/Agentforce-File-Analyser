import { LightningElement, api } from 'lwc';

export default class LlmDatatable extends LightningElement {
    // Public property to receive data and columns configuration from the parent component
    @api tabledata = {}; // Object containing columns and data

    get name(){
        return this.tabledata.name || 'Unknown name';
    }

    get description(){
        return this.tabledata.description || 'Unknown description';
    }

    get columns() {
        return this.tabledata.columns || [];
    }

    get data() {
        return this.tabledata.data || [];
    }
}