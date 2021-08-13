public inherited sharing class RTV_DEF_OffPolicy_Export {
    public RTV_Defective__c program {get; set;}
    public String programId = ApexPages.currentPage().getParameters().get('id');
    public List<RTV_DEF_Expected_Result__c> listlines {get; set;}
    public RTV_DEF_Expected_Result__c expect1 {get; set;}
    public RTV_DEF_Expected_Result__c expect2 {get; set;}
    public RTV_DEF_Expected_Result__c expect3 {get; set;}
    public RTV_DEF_Expected_Result__c expect4 {get; set;}
    public RTV_DEF_Expected_Result__c expect5 {get; set;}
    
    public RTV_DEF_OffPolicy_Export() {
        this.program = [
            SELECT Id, 
            Name,Start_Date__c,End_Date__c,Budget_Amount__c,Program_Rate__c,Requested_by__r.Name,CreatedDate,Defective_Auth_Code__c,Actual_Amount__c,
            Currency__c,Job_Title__c,Department__c,
            Program_Objective__c,Background__c,Program_mechanism__c
            FROM RTV_Defective__c
            WHERE Id = :this.programId limit 1
        ];

        this.listlines = [
                SELECT Return_Product_Descripton__c,No_of_Target_return_SKU__c,Return_Product_offer_season__c,Total_Units__c,Original_Wholesale_Price__c,
                Landing_Cost__c,P_L_Impact__c,Estimated_claim_from_factory__c,Action_after_return__c
                FROM RTV_DEF_Expected_Result__c
                WHERE RTV_DEF_Program__c = :this.programId
        ];
        Integer size = this.listlines.size();

        RTV_DEF_Expected_Result__c total = new RTV_DEF_Expected_Result__c();
        total.Return_Product_Descripton__c = 'TTL';
        total.Total_Units__c = 0;
        total.Original_Wholesale_Price__c = 0;
        total.Landing_Cost__c = 0;
        total.P_L_Impact__c = 0;
        total.Estimated_claim_from_factory__c = 0;
        for( RTV_DEF_Expected_Result__c item:this.listlines){
            if(item.Total_Units__c!=null){
                total.Total_Units__c += item.Total_Units__c;
            }
            if(item.Original_Wholesale_Price__c!=null){
                total.Original_Wholesale_Price__c += item.Original_Wholesale_Price__c;
            }
            if(item.Landing_Cost__c!=null){
                total.Landing_Cost__c += item.Landing_Cost__c;
            }
            if(item.P_L_Impact__c!=null){
                total.P_L_Impact__c += item.P_L_Impact__c;
            }
            if(item.Estimated_claim_from_factory__c!=null){
                total.Estimated_claim_from_factory__c += item.Estimated_claim_from_factory__c;
            }   
        }

        if(size>0){
            this.expect1 = this.listlines.get(0);
        }else {
            this.expect1 = new RTV_DEF_Expected_Result__c();
        }
        if(size>1){
            this.expect2 = this.listlines.get(1);
        }else{
            this.expect2 = new RTV_DEF_Expected_Result__c();
            if(size==1){
                this.expect2=total;
            }
        }
        if(size>2){
            this.expect3 = this.listlines.get(2);
        }else{
            this.expect3 = new RTV_DEF_Expected_Result__c();
            if(size==2){
                this.expect3=total;
            }
        }
        if(size>3){
            this.expect4 = this.listlines.get(3);
        }else{
            this.expect4 = new RTV_DEF_Expected_Result__c();
            if(size==3){
                this.expect4=total;
            }
        }
        if(size>4){
            this.expect5 = this.listlines.get(4);
        }else{
            this.expect5 = new RTV_DEF_Expected_Result__c();
            if(size==4){
                this.expect5=total;
            }
        }

    }
}