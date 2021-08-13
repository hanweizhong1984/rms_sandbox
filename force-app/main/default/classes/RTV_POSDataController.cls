public class RTV_POSDataController {

    private ApexPages.StandardSetController standardSetController;

    public RTV_POSDataController(ApexPages.StandardSetController standardSetController) {
        this.standardSetController = standardSetController;

        List<RTV_POS_Data__c> selectedListViewRecords = (List<RTV_POS_Data__c>)standardSetController.getSelected();
        standardSetController.setSelected(selectedListViewRecords);
    }

    /** 返回list页面 */
    public PageReference cancel(){
        // reback page
        PageReference pg = new PageReference('/lightning/o/RTV_POS_Data__c/list');
        pg.setRedirect(true);
        return pg;
    }

    public PageReference deleteData()
    {
        List<RTV_POS_Data__c> allListViewRecords = (List<RTV_POS_Data__c>)standardSetController.getRecords();
        List<RTV_POS_Data__c> selectedListViewRecords = (List<RTV_POS_Data__c>)standardSetController.getSelected();

        if(selectedListViewRecords.size() < 1){
            delete allListViewRecords;
        }else {
            delete selectedListViewRecords;
        }
        // reback page
        PageReference pg = new PageReference('/lightning/o/RTV_POS_Data__c/list');
        pg.setRedirect(true);
        return pg;
    }
}