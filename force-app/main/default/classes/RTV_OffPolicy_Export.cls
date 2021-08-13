public inherited sharing class RTV_OffPolicy_Export {
    public RTV_Program__c program {get; set;}
    public String programId = ApexPages.currentPage().getParameters().get('id');
    public List<RTV_RP_Summary_Budget__c> budgets{get;set;} 
    public RTV_RP_Summary_Budget__c budget1 {get; set;}
    public RTV_RP_Summary_Budget__c budget2 {get; set;}
    public RTV_RP_Summary_Budget__c budget3 {get; set;}
    public RTV_RP_Summary_Budget__c budget4 {get; set;}
    public RTV_RP_Summary_Budget__c budget5 {get; set;}
    public RTV_RP_Summary_Budget__c budget6 {get; set;}
    public RTV_RP_Summary_Budget__c budget7 {get; set;}
    public RTV_RP_Summary_Budget__c budget8 {get; set;}
    public RTV_RP_Summary_Budget__c budget9 {get; set;}
    public RTV_RP_Summary_Budget__c budget10 {get; set;}
    public RTV_RP_Summary_Budget__c budget11 {get; set;}
    public RTV_RP_Summary_Budget__c budget12 {get; set;}
    public RTV_RP_Summary_Budget__c budget13 {get; set;}
    public RTV_RP_Summary_Budget__c budget14 {get; set;}
    public RTV_RP_Summary_Budget__c budget15 {get; set;}
    public String printType {get; set;}
    public Boolean isOpening {get; set;}
    public RTV_OffPolicy_Export() {
        this.isOpening = true;
        this.program = [
            SELECT Name,Finance_Code__c,
            Program_Period__c,Expiration_Date__c,Create_Date__c,
            Budget_Amount_NET__c,Actual_Amount__c,
            Program_Rate__c,Currency__c, Request_by__c,Job_Title__c,Department__c
            FROM RTV_Program__c 
            WHERE Id=:this.programId LIMIT 1
        ];

        this.budgets =[
            SELECT Id, Account_Group__r.Name,
            QTY__c,MSRP__c,Tack_Back_Net__c
            FROM RTV_RP_Summary_Budget__c 
            WHERE Return_Program__c = :this.programId
        ];
        Integer size = this.budgets.size();
        RTV_RP_Summary_Budget__c total = new RTV_RP_Summary_Budget__c();
        total.QTY__c = 0;
        total.MSRP__c = 0;
        total.Tack_Back_Net__c = 0;
        for( RTV_RP_Summary_Budget__c item:this.budgets){
            if(item.QTY__c!=null){
                total.QTY__c += item.QTY__c;
            }
            if(item.MSRP__c!=null){
                total.MSRP__c += item.MSRP__c;
            }
            if(item.Tack_Back_Net__c!=null){
                total.Tack_Back_Net__c += item.Tack_Back_Net__c;
            }
        }


        if(size > 0){
            this.budget1 = this.budgets.get(0);
        }else {
            this.budget1 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 1){
            this.budget2 = this.budgets.get(1);
        }else {
            this.budget2 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 2){
            this.budget3 = this.budgets.get(2);
        }else {
            this.budget3 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 3){
            this.budget4 = this.budgets.get(3);
        }else {
            this.budget4 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 4){
            this.budget5 = this.budgets.get(4);
        }else {
            this.budget5 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 5){
            this.budget6 = this.budgets.get(5);
        }else {
            this.budget6 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 6){
            this.budget7 = this.budgets.get(6);
        }else {
            this.budget7 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 7){
            this.budget8 = this.budgets.get(7);
        }else {
            this.budget8 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 8){
            this.budget9 = this.budgets.get(8);
        }else {
            this.budget9 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 9){
            this.budget10 = this.budgets.get(9);
        }else {
            this.budget10 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 10){
            this.budget11 = this.budgets.get(10);
        }else {
            this.budget11 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 11){
            this.budget12 = this.budgets.get(11);
        }else {
            this.budget12 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 12){
            this.budget13 = this.budgets.get(12);
        }else {
            this.budget13 = new RTV_RP_Summary_Budget__c();
        }
        if(size > 13){
            this.budget14 = this.budgets.get(13);
        }else {
            this.budget14 = new RTV_RP_Summary_Budget__c();
        }
        this.budget15 = total;
    }

    public PageReference test() {
        this.isOpening = false;
        return null;
    }

    public List<SelectOption> getItems() {
        List<SelectOption> options = new List<SelectOption>(); 
        options.add(new SelectOption('Takeback','Takeback')); 
        options.add(new SelectOption('Recall','Recall'));
        return options; 
    }
   
}