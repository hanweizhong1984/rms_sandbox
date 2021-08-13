public class RMS_DeleteRecord_Batch implements Database.Batchable<SObject> {
    
    final String query;
    
    public RMS_DeleteRecord_Batch(String query) {
        this.query = query;
    }
    
    public Database.QueryLocator start(Database.BatchableContext info){ 
        return Database.getQueryLocator(this.query);
    }
    
    public void execute(Database.BatchableContext info, List<SObject> records) {
        delete records;
    }
    
    public void finish(Database.BatchableContext info){
    }
}