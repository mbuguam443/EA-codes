#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include<Trade/Trade.mqh>
CTrade trade;


input int CloseTimeHour=18;
input int CloseTimeMin=0;
input double Lots=0.01;


bool isPreDayHighTriggered,isPrevDayLowTriggered;
int barsTotalD1;

int OnInit(){
   
   
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason){

   
  }
void OnTick(){
     
     int barsD1=iBars(_Symbol,PERIOD_D1);
     if(barsTotalD1!=barsD1)
       {
        barsTotalD1=barsD1;
        isPreDayHighTriggered=false;
        isPrevDayLowTriggered=false;
       }
      double highD1=iHigh(_Symbol,PERIOD_D1,1);
      double lowD1=iLow(_Symbol,PERIOD_D1,1);
      
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      
      if(!isPreDayHighTriggered && bid>=highD1)
        {
         trade.Buy(Lots, NULL, 0, 0, 0, "My Comment");
         if(trade.ResultOrder()>0)
           {
             isPreDayHighTriggered=true;
           }
         
        }
      if(!isPrevDayLowTriggered && bid<=lowD1)
        {
         trade.Sell(Lots, NULL, 0, 0, 0, "My Comment");
         if(trade.ResultOrder()>0)
           {
             isPrevDayLowTriggered=true;
           }
         
        }  
   
     MqlDateTime structTime;
     TimeCurrent(structTime);
     
     structTime.sec=0;
     structTime.hour=CloseTimeHour;
     structTime.min=CloseTimeMin;
     
     datetime timeClose=StructToTime(structTime);
     
     if(TimeCurrent() >=timeClose)
       {
         for(int i=PositionsTotal()-1;i>=0;i--)
           {
             ulong posTickect=PositionGetTicket(i);
             if(PositionSelectByTicket(posTickect))
               {
                if(PositionGetString(POSITION_SYMBOL)==_Symbol)
                  {
                   trade.PositionClose(posTickect);
                  }
               }
           }
       }
  }

