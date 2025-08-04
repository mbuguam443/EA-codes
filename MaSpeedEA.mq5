//+------------------------------------------------------------------+
//|                                                    MaSpeedEA.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int handleMASpeed;

int totalBars;

int OnInit()
  {
    
   handleMASpeed=iCustom(_Symbol,PERIOD_CURRENT,"Market/MASpeed.ex5"); 
   if(handleMASpeed==INVALID_HANDLE)
     {
      Print("Failed to Load Indicator MASpeed");
     }else
        {
         Print("Loaded Successfully");
        }
   totalBars=iBars(_Symbol,PERIOD_CURRENT); 
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   
   int bars=iBars(_Symbol,PERIOD_CURRENT);
   //if(totalBars!=bars)
     {
      totalBars=bars;
     
      double maspeedBuffer[],signalUp[],signalDown[];
      
      ArraySetAsSeries(maspeedBuffer,true);
      ArraySetAsSeries(signalDown,true);
      ArraySetAsSeries(signalUp,true);
      CopyBuffer(handleMASpeed,0,1,1,maspeedBuffer);
      CopyBuffer(handleMASpeed,1,1,1,signalUp);
      CopyBuffer(handleMASpeed,3,1,1,signalDown);
      Print("buffervalue: ",maspeedBuffer[0]," signalUp: ",signalUp[0]," signalDown: ",signalDown[0]);  
      
     }
   
  }
//+------------------------------------------------------------------+
