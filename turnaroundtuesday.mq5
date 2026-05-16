#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include<Trade/Trade.mqh>
input ENUM_TIMEFRAMES Timeframe=PERIOD_M1;
input double RiskPercent=100;
input double SlPercent=5;

input int DayOpen=1;
input int TimeOpenHour=22;
input int TimeOpenMin=55;


input int DayClose=2;
input int TimeCloseHour=22;
input int TimeCloseMin=55;

input bool IsMaFilter=true;
input ENUM_TIMEFRAMES MaTimeFrame=PERIOD_D1;
input int MaPeriods=20;
input ENUM_MA_METHOD MaMethod=MODE_SMA;
input ENUM_APPLIED_PRICE MaPrice=PRICE_CLOSE;


int barsTotal;
int handleMa;
CTrade trade;
int LastDay=0;
ulong myticket=0;



int OnInit()
  {
    
    handleMa=iMA(_Symbol,MaTimeFrame,MaPeriods,0,MaMethod,MaPrice);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    
    int bars=iBars(_Symbol,Timeframe);
    if(barsTotal!=bars)
      {
        barsTotal=bars;
        double ma[];
        
        CopyBuffer(handleMa,MAIN_LINE,0,1,ma);
        
        
        MqlDateTime dt;
        TimeCurrent(dt);
        dt.hour=TimeOpenHour;
        dt.min=TimeOpenMin;
        dt.sec=0;
        datetime timeOpen=StructToTime(dt);
        
        if(LastDay!=dt.day_of_year && TimeCurrent()>=timeOpen && dt.day_of_week==DayOpen)
          {
             if(SymbolInfoDouble(_Symbol,SYMBOL_BID)<ma[0] || !IsMaFilter)
               {
               if(myticket==0)
                 {
                      double ask =SymbolInfoDouble(_Symbol,SYMBOL_ASK);
                      double sl=ask-ask*SlPercent;
                      double lots=CalculateLotSize(SlPercent,ask-sl);
                      if(trade.Buy(0.01,_Symbol,ask,sl,0," turn around tuesday"))
                      {
                          Print("hello there Day of week: ",DayOpen," ",timeOpen);
                         LastDay=dt.day_of_year;
                         myticket=trade.ResultOrder();
                         Print("Ticket: ",myticket," Descrip: ",trade.ResultRetcodeDescription());
                      }
                 }                
               }
          }
          
        dt.hour=TimeCloseHour;
        dt.min=TimeCloseMin;
        dt.sec=0;
        datetime timeClose=StructToTime(dt);  
        if(LastDay!=dt.day_of_year && TimeCurrent()>=timeClose && dt.day_of_week==DayClose)
          {
            
            if(myticket>0)
              {
               if(trade.PositionClose(myticket))
                 {
                  myticket=0;
                  Print("Closing Position=====Day of week:",DayClose," ",timeClose);
                 }else
                    {
                     Print("Failed to close the position");
                    }
              }
          }
      }
   
  }
//+------------------------------------------------------------------+
double CalculateLotSize(int Percent,double slDistance)
{
   double tickSize= SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue= SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ticklotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double ticklotMin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double ticklotMax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   
   Print("tickSize: ",tickSize," tickValue: ",tickValue," tickLotStep: ",ticklotStep," tickMin: ",ticklotMin," tickmax: ",ticklotMax);
   
   if(tickSize==0 || tickValue==0 || ticklotStep==0 )
     {
       return 0;
     }
     
   double riskMoney= AccountInfoDouble(ACCOUNT_EQUITY)*Percent/100;
   
   double moneyPerSmallestLotsize= (slDistance/tickSize)*tickValue*ticklotStep;
   Print("slDistance: ",slDistance,"riskMoney: ",riskMoney," smallest you can riskMoney: ",moneyPerSmallestLotsize);
   if(moneyPerSmallestLotsize==0)
     {
      return 0;
     }
   double lotsFactor= (riskMoney/moneyPerSmallestLotsize);  
   double lots= MathFloor(riskMoney/moneyPerSmallestLotsize)* ticklotStep;
   if(moneyPerSmallestLotsize >riskMoney)
     {
      lots=ticklotMin;
     }
   if(lots > ticklotMax)
     {
      lots=ticklotMax;
     }  
   Print("The Lot Factor between the two is: ",lotsFactor);
   Print("The Lots size to be used: ",lots);
   return lots; 
    
}
