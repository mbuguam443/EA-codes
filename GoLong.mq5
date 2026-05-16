//+------------------------------------------------------------------+
//| Daily Buy EA - Simple Version                                    |
//| Opens one BUY when the first bar reaches/passes 01:55            |
//| Closes all BUY positions when the first bar reaches/passes 23:00 |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

//--- Inputs
input double LotSize     = 0.01;
input int    MagicNumber = 12345;

bool longopen=false;



//+------------------------------------------------------------------+
//| Open BUY                                                         |
//+------------------------------------------------------------------+
void OpenBuy()
{
   if(trade.Buy(LotSize, _Symbol,0,0,0,"Go long"))
   {
      Print("BUY opened successfully at ",
            TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
            longopen=true;
   }
   else
   {
      Print("BUY failed. Retcode = ",
            trade.ResultRetcode(),
            " - ",
            trade.ResultRetcodeDescription());
            longopen=false;
   }
}

//+------------------------------------------------------------------+
//| Close all BUY positions opened by this EA                        |
//+------------------------------------------------------------------+
void CloseBuyPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      // Only close BUY positions opened by this EA
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         if(trade.PositionClose(ticket))
         {
            Print("Closed BUY ticket ", ticket,
                  " at ",
                  TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
                  longopen=false;
         }
         else
         {
            Print("Failed to close ticket ", ticket,
                  ". Retcode = ",
                  trade.ResultRetcode(),
                  " - ",
                  trade.ResultRetcodeDescription());
                  longopen=true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   Print("Daily Buy EA initialized.");
  
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
  
  
      
  
  
      datetime dayStart=TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(dayStart, dt);
   
      // Open time = 01:55
      dt.hour = 1;
      dt.min  = 55;
      dt.sec  = 0;
      datetime openTime = StructToTime(dt);
   
      // Close time = 23:00 (you confirmed this detects correctly)
      dt.hour = 23;
      dt.min  = 0;
      dt.sec  = 0;
      datetime closeTime = StructToTime(dt);
   
      // Current bar open time
      datetime barTime = TimeCurrent();
   
      //---------------------------------------------------------------
      // OPEN BUY ONCE PER DAY
      //---------------------------------------------------------------
      if(!longopen && barTime >= openTime)
      {
        Print("==============Opening Long Trade=======================",barTime);
         //lastOpenDay = dayStart;
         OpenBuy();
         
      }
   
      //---------------------------------------------------------------
      // CLOSE BUY ONCE PER DAY
      //---------------------------------------------------------------
      if(longopen && barTime >= closeTime)
      {
         Print("=============Closing the long trade============================",barTime);
         //lastCloseDay = dayStart;
         CloseBuyPositions();
         
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
