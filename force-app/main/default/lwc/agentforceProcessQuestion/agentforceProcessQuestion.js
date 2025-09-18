/**
 * @date    June 2025
 * @author  Justus van den Berg (jfwberg@gmail.com)
 * @note    This is for demo purposes only
 */
import { api,track }        from 'lwc';
import { LightningElement } from 'lwc';
import LightningAlert       from 'lightning/alert';

// Apex methods
import ask          from "@salesforce/apex/AgentforceProcessQuestionCtrl.ask";

// Main logic
export default class AgentforceProcessQuestion extends LightningElement {

    // Record Id for the process
    @api recordId;

    // Loading indicator for the spinner
    loading = false;

    // LLM picklist
    modelSelected = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
    modelOptions  = [
        { label: 'OpenAI GPT 4 Omni Mini', value: 'sfdc_ai__DefaultOpenAIGPT4OmniMini', default: true },
        { label: 'Google Gemini 2.5 Pro',  value: 'sfdc_ai__DefaultVertexAIGeminiPro25'}
    ];

    // The question that we can use to ask the user
    question = 'Please give a brief summary of the process';

    // LLM Response
    response;

    // Indicator if the response should be shown
    showResponse = false;

    // Get the response
    get llmResponse(){
        return this.mdToHtmlAdvanced(this.response.llmResponse);
    }


    /** **************************************************************************************************** **
     **                                        FILE RELATED HANDLERS                                         **
     ** **************************************************************************************************** **/
    handleAsk() {
        try{
            this.loading = true;

            // Execute Apex
            ask({
                modelName   : this.modelSelected,
                recordId    : this.recordId,
                question    : this.question,
                
            })
            .then((apexResponse) => {
                
                // Update the response
                this.response = apexResponse;

                // Switch flag
                this.showResponse = true;

                // Remove spinner
                this.loading = false;
            })
            .catch((error) => {
                this.loading = false;
                this.handleError(error);
            })
        }catch(error){
            this.loading = false;
            this.handleError(error);
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


    mdToHtmlAdvanced(md) {
        if (!md) return '';

        // 0) Normalize
        let text = String(md).replace(/\r\n?/g, '\n');

        // Make inline " * " bullets into real lines without harming *italic*
        text = text.replace(/\s([*-])\s(?=\S)/g, '\n$1 ');

        // 1) Fenced code blocks (protect with placeholders)
        const codeBlocks = [];
        text = text.replace(/```([\w-]+)?\n([\s\S]*?)\n```/g, (_, lang, body) => {
            const i = codeBlocks.length;
            codeBlocks.push(
            `<pre><code${lang ? ` class="language-${lang}"` : ''}>${this._escapeHTML(body)}</code></pre>`
            );
            return `\u0000CODEBLOCK_${i}\u0000`;
        });

        // 2) Escape HTML
        text = this._escapeHTML(text);

        // 3) Headings
        for (let n = 6; n >= 1; n--) {
            const re = new RegExp(`^#{${n}}\\s+(.+)$`, 'gm');
            text = text.replace(re, `<h${n}>$1</h${n}>`);
        }

        // 4) Horizontal rules
        text = text.replace(/^(?:-{3,}|\*{3,}|_{3,})\s*$/gm, '<hr/>');

        // 5) Blockquotes
        text = text.replace(/^(>\s?)(.+)$/gm, (_, __, body) => `<blockquote>${body}</blockquote>`);

        // 6) Blocks → paragraphs/lists (now supports lists starting mid-block)
        const blocks = text.split(/\n{2,}/);
        const out = [];

        for (const rawBlock of blocks) {
            const block = rawBlock; // already escaped
            if (/^<h[1-6]>|^<hr\/>|^<blockquote>/.test(block.trim())) {
            out.push(block);
            continue;
            }

            const lines = block.split('\n');
            let mode = null; // 'ul' | 'ol' | null
            let para = [];

            const closePara = () => {
            if (para.length) {
                out.push(`<p>${para.join('<br/>')}</p>`);
                para = [];
            }
            };
            const closeList = () => {
            if (mode === 'ul') out.push('</ul>');
            if (mode === 'ol') out.push('</ol>');
            mode = null;
            };

            for (let l of lines) {
            // UL item?
            const ulm = l.match(/^\s*([*-+])\s+(.*)$/);
            if (ulm) {
                if (mode === 'ol') closeList();
                if (mode !== 'ul') { closePara(); out.push('<ul>'); mode = 'ul'; }
                let item = ulm[2];
                // Task list checkbox: - [ ] / - [x]
                item = item.replace(/^\[( |x|X)\]\s+/, (m, chk) => (chk.trim() ? '☑︎ ' : '☐ '));
                out.push(`<li>${this._inline(item)}</li>`);
                continue;
            }

            // OL item?
            const olm = l.match(/^\s*\d+\.\s+(.*)$/);
            if (olm) {
                if (mode === 'ul') closeList();
                if (mode !== 'ol') { closePara(); out.push('<ol>'); mode = 'ol'; }
                out.push(`<li>${this._inline(olm[1])}</li>`);
                continue;
            }

            // Normal text line
            if (mode) closeList();
            para.push(this._inline(l));
            }

            if (mode) closeList();
            closePara();
        }

        // 7) Restore code blocks
        let html = out.join('\n');
        html = html.replace(/\u0000CODEBLOCK_(\d+)\u0000/g, (_, i) => codeBlocks[Number(i)]);
        return html;
        }


    // ----- Inline formatting helpers -----
    _inline(s) {
        if (!s) return '';

        // Protect inline code first: `code`
        const codes = [];
        s = s.replace(/`([^`]+)`/g, (_, body) => {
        const i = codes.length;
        codes.push(`<code>${body}</code>`);
        return `\u0000INCODE_${i}\u0000`;
        });

        // Links: [text](url)  (http/https only)
        s = s.replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, '<a href="$2" rel="noopener" target="_blank">$1</a>');

        // Bold: **text**
        s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');

        // Italic: *text*  (avoid matching list markers and bold)
        s = s.replace(/(^|[\s(])\*([^*\s][^*]*?)\*(?=[\s).]|$)/g, '$1<em>$2</em>');

        // Restore inline code
        s = s.replace(/\u0000INCODE_(\d+)\u0000/g, (_, i) => codes[Number(i)]);

        return s;
    }

    _escapeHTML(str) {
        return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
    }
    
}