public with sharing class RTV_Bth_SKU_KPI_Del implements Database.Batchable<sObject>, Database.Stateful {

    final String query;
    
    public RTV_Bth_SKU_KPI_Del(String query) {
        this.query = query;
    }
    
    public Database.QueryLocator start(Database.BatchableContext info){ 
        return Database.getQueryLocator(this.query);
    }
    
    public void execute(Database.BatchableContext info, List<SObject> records) {
        delete records;
    }
    
    public void finish(Database.BatchableContext info){
        RTV_Bth_SKU_KPI insbth = new RTV_Bth_SKU_KPI();
        // SOQL query results 
        // Maximum rows returned 
        // 2,000 results total (API version 28.0 and later)
        Database.executebatch(insbth, 1000);
    }
}