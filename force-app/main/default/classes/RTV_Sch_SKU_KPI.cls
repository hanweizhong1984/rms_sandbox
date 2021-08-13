global class RTV_Sch_SKU_KPI implements Schedulable {

    global void execute(SchedulableContext sc){
        // RESET SKU KPI
        // RTV_Bth_SKU_KPI_Del bth = new RTV_Bth_SKU_KPI_Del('SELECT Id FROM RTV_SKU_KPI__c WHERE Current_Status__c != \'Completed\'');
        RTV_Bth_SKU_KPI_Del bth = new RTV_Bth_SKU_KPI_Del('SELECT Id FROM RTV_SKU_KPI__c');
        Database.executebatch(bth, 5000);
    }
}