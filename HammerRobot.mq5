#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

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
    getHammerSignal();   
  }
//+------------------------------------------------------------------+


int getHammerSignal()
{
  double high=iHigh(_Symbol,PERIOD_CURRENT,1);
  double low=iLow(_Symbol,PERIOD_CURRENT,1);
  datetime time=iTime(_Symbol,PERIOD_CURRENT,1);
  double open=iOpen(_Symbol,PERIOD_CURRENT,1);
  double close=iClose(_Symbol,PERIOD_CURRENT,1);
  
  //green hammer
  if(open<close)
    {
     double candleSize=high-low;
      if((high-close)<0.1)
      {
        if((open-low)>0.6)
          {
            createObj(time,low,233);
            return 1;
          }
      }
    }
    
    //green hammer
  if(open>close)
    {
     double candleSize=high-low;
      if((high-open)<0.1)
      {
        if((close-low)>0.6)
          {
            createObj(time,low,233);
            return 1;
          }
      }
    }
  return 0;
}

void createObj(datetime time, double price, int arrowCode)
{
   string objName;
   StringConcatenate(objName,"Signal@",time,"at",DoubleToString(price,_Digits)," (",arrowCode,")");
   if(ObjectCreate(0,objName,OBJ_ARROW,0,time,price))
     {
        ObjectSetInteger(0,objName,OBJPROP_ARROWCODE,arrowCode);
     }
  
}