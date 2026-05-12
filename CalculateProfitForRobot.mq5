#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){

   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason){

   
  }
void OnTick(){
    CalcDailyClosedProfit();
    
   
  }

double CalcDailyClosedProfit()
{
   double totalProfit=0.0;
   
  MqlDateTime dt;
  TimeCurrent(dt);
  
  dt.hour=0;
  dt.min=0;
  dt.sec=0;
  
  datetime timeDaystart=StructToTime(dt); 
   
   
  HistorySelect(timeDaystart,TimeCurrent()+100);
  for(int i=HistoryDealsTotal()-1;i>=0;i--)
    {
        ulong dealTicket=HistoryDealGetTicket(i);
        int dealType = (int)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        if (dealType==DEAL_ENTRY_OUT)
         {
           double dealProfit=HistoryDealGetDouble(dealTicket,DEAL_PROFIT);
           double dealCommission=HistoryDealGetDouble(dealTicket,DEAL_COMMISSION);
           
           Print("Ticket: ",dealTicket," profit: ",dealProfit," commission: ",dealCommission);
         }
    }
   
   return totalProfit;
}