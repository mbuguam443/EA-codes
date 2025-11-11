#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
input int InpMagic=2343;
input double Riskpercent=2;
input int RangeStartHour=3;
input int RangeStartMin=0;
input int RangeEndHour=6;
input int RangeEndMin=0;
input int TradingEndHour=18;
input int TradingEndMin=0;


datetime rangeTimeStart;
datetime rangeTimeEnd;
datetime tradingTimeEnd;

double rangeHigh,rangeLow;
CTrade trade;
bool isTrade;

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
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

   calcTimes();
   calcRange();
   
   if(TimeCurrent()>rangeTimeEnd && TimeCurrent() <tradingTimeEnd)
     {
         double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
            if(TimeCurrent()>rangeTimeEnd)
           {
           if(isTrade==false)
             {
              if(rangeHigh>0 && rangeLow>0)
              {
                 if(bid>rangeHigh)
                 {
                  double lots=calcLots();
                  trade.Buy(lots,_Symbol,0,rangeLow);
                  isTrade=true;
                 }else if(bid< rangeLow)
                 {
                  double lots=calcLots(); 
                  trade.Sell(lots,_Symbol,0,rangeHigh);
                  isTrade=true;         
                 }
              }
             }       
           }
     }else if(TimeCurrent()>=tradingTimeEnd)
     {
            for(int i=PositionsTotal()-1;i>=0;i--)
              {
               CPositionInfo pos;
               if(pos.SelectByIndex(i))
                 {
                  if(pos.Magic()==InpMagic)
                    {
                     trade.PositionClose(pos.Ticket());
                    }
                 }
              }  
     }
   
   
   
   
  }
//+------------------------------------------------------------------+

void calcTimes()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.sec=0;
   dt.hour=RangeStartHour;
   dt.min=RangeStartMin;
   
   
   if(rangeTimeStart!=StructToTime(dt))
     {
      isTrade=false;
      rangeHigh=0;
      rangeLow=0;
     }
   rangeTimeStart=StructToTime(dt);
   
   dt.hour=RangeEndHour;
   dt.min=RangeEndMin;
   rangeTimeEnd=StructToTime(dt);
   
   dt.hour=TradingEndHour;
   dt.min=TradingEndMin;
   
   tradingTimeEnd=StructToTime(dt);
}

void calcRange()
{
  double highs[];
  CopyHigh(_Symbol,PERIOD_CURRENT,rangeTimeStart,rangeTimeEnd,highs);
  double lows[];
  CopyLow(_Symbol,PERIOD_CURRENT,rangeTimeStart,rangeTimeEnd,lows);
  
  if(ArraySize(highs)<1 || ArraySize(lows)<1)return;
  
  int indexHighest=ArrayMaximum(highs);
  int indexLowest=ArrayMinimum(lows);
  
  rangeHigh=highs[indexHighest];
  rangeLow=lows[indexLowest];
  
  string objName="Range "+TimeToString(rangeTimeStart,TIME_DATE);
  string objLine="Range "+TimeToString(rangeTimeEnd,TIME_DATE);
  //ObjectCreate(0,objLine,OBJ_TREND,0,rangeTimeEnd,rangeHigh);
  if(ObjectFind(0,objName)<0)
  {
     ObjectCreate(0,objName,OBJ_RECTANGLE,0,rangeTimeStart,rangeLow,rangeTimeEnd,rangeHigh);
     ObjectSetInteger(0,objName,OBJPROP_FILL,true);
     ObjectSetInteger(0,objName,OBJPROP_COLOR,clrYellow);
  }else
     {
      ObjectSetDouble(0,objName,OBJPROP_PRICE,0,rangeLow);
      ObjectSetDouble(0,objName,OBJPROP_PRICE,1,rangeHigh);
     }
 
  
}
double calcLots()
{
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double maxlot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double minlot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   
   double rangeSize=rangeHigh-rangeLow;
   double riskPerLot=rangeSize/tickSize*tickValue;
   
   double RiskMoney=Riskpercent*0.01*AccountInfoDouble(ACCOUNT_BALANCE);
   
   double lots=RiskMoney/riskPerLot;
   
   lots=NormalizeDouble(lots,2);
   
   Print("Lots: ",lots," RiskMoney:",RiskMoney," riskPerLot: ",riskPerLot);
   if(lots>maxlot)
     {
      lots=maxlot;
     }else if(lots<minlot)
     {
       lots=minlot;     
     }
   return lots;
}