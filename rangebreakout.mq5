//+------------------------------------------------------------------+
//|                                                rangebreakout.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//|Inputs                                                            |
//+------------------------------------------------------------------+
input group "====General Inputs==="
input long InpMagicNumber=12345; //magic number

enum LOT_MODE_ENUM{
  LOT_MODE_FIXED,  // fixed lots
  LOT_MODE_MONEY,  //lot based on money
  LOT_MODE_PCT_ACCOUNT //lots based on percent of account (lot must be %)
};
input LOT_MODE_ENUM InpLotMode=LOT_MODE_PCT_ACCOUNT; //lot mode

input double InpLots=4;       //lots / money/ %

input int InpTakeProfit=0;       //TakeProfit in % of the range (0=off)
input int InpStopLoss=90;        //stop loss in % of the range  (0=off)
input bool InpStopLossTrailing=false; // Trailing stop loss
input group "Range Setting"
input int InpRangeStart=90;     // range start time in minutes
input int InpRangeDuration=270;   // range duration in minutes
input int InpRangeClose=1200 ;    //range close time in minutes (-1=off)

enum BREAKOUT_MODE_ENUM{
    ONE_SIGNAL,                   //one signal per breakout range
    TWO_SIGNAL,                   //two signal per breakout range (high,low)
};

input BREAKOUT_MODE_ENUM InpBreakoutMode =ONE_SIGNAL;  //breakout mode
input group "====RangeDays Inputs==="
input bool InpMonday=true;        // range on Monday 
input bool InpTuesday=true;        // range on Tuesday
input bool InpWednesday=true;        // range on Wednesday
input bool InpThursday=true;        // range on Thursday
input bool InpFriday=true;        // range on Friday
//+------------------------------------------------------------------+
//| global variable                                                  |
//+------------------------------------------------------------------+

struct RANGE_STRUCT
  {
   datetime start_time; //start of the range
   datetime end_time;   //end of the range
   datetime close_time; //close time
   double high;         //high of the range
   double low;          //low of the range
   bool f_entry;        //flag if we are inside the range
   bool f_high_breakout; // flag if a high breakout occurred
   bool f_low_breakout;  //flag if a low breakout occurred
   
   RANGE_STRUCT() : start_time(0),end_time(0),close_time(0),high(0),low(DBL_MAX),f_entry(false),f_high_breakout(false),f_low_breakout(false){};
   
  };

RANGE_STRUCT range;
MqlTick prevTick, lastTick;  
CTrade trade;


int OnInit()
  {
  
      if(!CheckInputs())
      {
          return INIT_PARAMETERS_INCORRECT;
      }
         
       if(_UninitReason==REASON_PARAMETERS && CountOpenPositions()==0)
      {
        CalculateRange();
      }
      trade.SetExpertMagicNumber(InpMagicNumber);
      
     //Draw Objects again when change in TimeFrame 
      DrawObjects(); 
         
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
   
   //Get current tick
   prevTick=lastTick;
   SymbolInfoTick(_Symbol,lastTick);
   //range calculation
   if(lastTick.time >= range.start_time && lastTick.time < range.end_time)
     {
       //set flag
       range.f_entry=true;
       //new high
       if(lastTick.ask > range.high)
         {
          range.high=lastTick.ask;
          DrawObjects();
         }
        //new low
       if(lastTick.bid < range.low)
         {
          range.low=lastTick.bid;
          DrawObjects();
         }  
     }
  //close positions
  if(InpRangeClose>=0 && lastTick.time >=range.close_time)
    {
      Print("Times up Go Home");
      if(!ClosePositions())
        {
         return;
        }
    }   
     
   
   //calculate new range if
   if(((InpRangeClose >=0 && lastTick.time >=range.close_time)
     || (range.f_high_breakout && range.f_low_breakout)
     || range.end_time==0
     || (range.end_time!=0 && lastTick.time > range.end_time && !range.f_entry))
     && CountOpenPositions()==0)
     {
      Print("Positons count: ",CountOpenPositions());
      //Print("Hello");
      CalculateRange();
     
     }
     //Print("open positions: ",CountOpenPositions());
    CheckBreakOut(); 
    
    //update StopTrailing
    if(InpStopLossTrailing)
      {
       UpdateStopLoss();
      }
   
  }
//+------------------------------------------------------------------+

//Check Breakout
void CheckBreakOut()
{
  if(lastTick.time>=range.end_time && range.end_time >0 && range.f_entry)
    {
      //check if we had a high breakout
      if(!range.f_high_breakout && lastTick.ask >=range.high)
        {
          range.f_high_breakout=true;
          if(InpBreakoutMode==ONE_SIGNAL){range.f_low_breakout=true;}
          //open a Position
          
          //calculate stoploss and Take profit
          double sl=InpStopLoss==0?0: NormalizeDouble(lastTick.bid-(range.high-range.low)*InpStopLoss*0.01,_Digits);
          double tp=InpTakeProfit==0?0:NormalizeDouble(lastTick.bid+(range.high-range.low)*InpTakeProfit*0.01,_Digits);
          //calculate lots
          double lots;
          if(!CalculateLots(lastTick.bid-sl,lots)){return;}
          
          trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,lots,lastTick.ask,sl,tp,"range buy");
        }
        
       //check if we had a low breakout
      if(!range.f_low_breakout && lastTick.bid <=range.low)
        {
          range.f_low_breakout=true;
          if(InpBreakoutMode==ONE_SIGNAL){range.f_high_breakout=true;}
          //open a Position
          
          //calculate stoploss and Take profit
          double sl=InpStopLoss==0?0:NormalizeDouble(lastTick.ask+(range.high-range.low)*InpStopLoss*0.01,_Digits);
          double tp=InpTakeProfit==0?0:NormalizeDouble(lastTick.ask-(range.high-range.low)*InpTakeProfit*0.01,_Digits);
          
          //calculate lots
          double lots;
          if(!CalculateLots(sl-lastTick.ask,lots)){return;}
          trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,lots,lastTick.bid,sl,tp,"range sell");
        }  
    }
}


//calculate new range
void CalculateRange()
{
 //reset range variables
  range.start_time=0;
  range.end_time=0;
  range.close_time=0;
  range.high=0.0;
  range.low=DBL_MAX;
  range.f_entry=false;
  range.f_high_breakout=false;
  range.f_low_breakout=false;
  
  //calculate range start time
  int time_cycle =86400;
  range.start_time=(lastTick.time - (lastTick.time % time_cycle)) +InpRangeStart*60;
  for(int i=0;i<8;i++)
    {
     MqlDateTime tmp;
     TimeToStruct(range.start_time,tmp);
     int dow=tmp.day_of_week;
     if(lastTick.time>=range.start_time || dow==6 || dow ==0 || (dow==1 && !InpMonday)|| (dow==2 && !InpTuesday)|| (dow==3 && !InpWednesday)|| (dow==4 && !InpThursday)|| (dow==5 && !InpFriday))
       {
        range.start_time+=time_cycle;
       }
    }
  range.end_time=range.start_time+InpRangeDuration*60; 
  
  for(int i=0;i<2;i++)
    {
     MqlDateTime tmp;
     TimeToStruct(range.end_time,tmp);
     int dow=tmp.day_of_week;
     if(dow==6 || dow==0)
       {
        range.end_time+=time_cycle;
       }
    } 
  
  //calculate range close
  if(InpRangeClose>0)
   {
     range.close_time=(range.end_time - (range.end_time % time_cycle)) +InpRangeClose*60;
     for(int i=0;i<3;i++)
       {
        MqlDateTime tmp;
        TimeToStruct(range.close_time,tmp);
        int dow=tmp.day_of_week;
        if(range.close_time<=range.end_time || dow==6 || dow ==0)
          {
           range.close_time+=time_cycle;
          }
       }
    }     
  //draw object
  DrawObjects();
}


void DrawObjects()
{
  //Print("yes man");
  //start
  //ObjectDelete(NULL,"range start");
  string rangestart = "range_start_" + IntegerToString(GetTickCount());
  if(range.start_time >0)
    {
      ObjectCreate(NULL,rangestart,OBJ_VLINE,0,range.start_time,0);
      ObjectSetString(NULL,rangestart,OBJPROP_TOOLTIP,"start of the range \n"+TimeToString(range.start_time,TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(NULL,rangestart,OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,rangestart,OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,rangestart,OBJPROP_BACK,true);
    }
  //end
  //ObjectDelete(NULL,"range end");
  string rangeend = "range_end_" + IntegerToString(GetTickCount());
  if(range.end_time >0)
    {
      ObjectCreate(NULL,rangeend,OBJ_VLINE,0,range.end_time,0);
      ObjectSetString(NULL,rangeend,OBJPROP_TOOLTIP,"end of the range \n"+TimeToString(range.end_time,TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(NULL,rangeend,OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,rangeend,OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,rangeend,OBJPROP_BACK,true);
    } 
    
  string rangeclose = "range_close_" + IntegerToString(GetTickCount());
  if(range.close_time >0)
    {
      ObjectCreate(NULL,rangeclose,OBJ_VLINE,0,range.close_time,0);
      ObjectSetString(NULL,rangeclose,OBJPROP_TOOLTIP,"close of the range \n"+TimeToString(range.close_time,TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(NULL,rangeclose,OBJPROP_COLOR,clrRed);
      ObjectSetInteger(NULL,rangeclose,OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,rangeclose,OBJPROP_BACK,true);
    }
    
  string rangehigh = "range_high_" + IntegerToString(GetTickCount());
  if(range.high >0)
    {
      ObjectCreate(NULL,rangehigh,OBJ_TREND,0,range.start_time,range.high,range.end_time,range.high);
      ObjectSetString(NULL,rangehigh,OBJPROP_TOOLTIP,"high of the range \n"+DoubleToString(range.high,_Digits));
      ObjectSetInteger(NULL,rangehigh,OBJPROP_COLOR,clrBlueViolet);
      ObjectSetInteger(NULL,rangehigh,OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,rangehigh,OBJPROP_BACK,true);
    
    
  string rangehighbreak = "range_highbreak_" + IntegerToString(GetTickCount());
 
      ObjectCreate(NULL,rangehighbreak,OBJ_TREND,0,range.end_time,range.high,range.close_time>0?range.close_time:(range.end_time + 3600),range.high);
      ObjectSetString(NULL,rangehighbreak,OBJPROP_TOOLTIP,"high breakout of the range \n"+DoubleToString(range.high,_Digits));
      ObjectSetInteger(NULL,rangehighbreak,OBJPROP_COLOR,clrBlueViolet);
      ObjectSetInteger(NULL,rangehighbreak,OBJPROP_BACK,true);
      ObjectSetInteger(NULL,rangehighbreak,OBJPROP_STYLE,STYLE_DOT);
    }   
    
  string rangelow = "range_low_" + IntegerToString(GetTickCount());
  if(range.low <DBL_MAX)
    {
      ObjectCreate(NULL,rangelow,OBJ_TREND,0,range.start_time,range.low,range.end_time,range.low);
      ObjectSetString(NULL,rangelow,OBJPROP_TOOLTIP,"low of the range \n"+DoubleToString(range.low,_Digits));
      ObjectSetInteger(NULL,rangelow,OBJPROP_COLOR,clrAzure);
      ObjectSetInteger(NULL,rangelow,OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,rangelow,OBJPROP_BACK,true);
      
      string rangelowbreak = "range_lowbreak_" + IntegerToString(GetTickCount());
 
      ObjectCreate(NULL,rangelowbreak,OBJ_TREND,0,range.end_time,range.low,range.close_time>0?range.close_time:(range.end_time + 3600),range.low);
      ObjectSetString(NULL,rangelowbreak,OBJPROP_TOOLTIP,"low breakout of the range \n"+DoubleToString(range.low,_Digits));
      ObjectSetInteger(NULL,rangelowbreak,OBJPROP_COLOR,clrBeige);
      ObjectSetInteger(NULL,rangelowbreak,OBJPROP_BACK,true);
      ObjectSetInteger(NULL,rangelowbreak,OBJPROP_STYLE,STYLE_DOT);
    } 
    
    
   //refresh chart    
   ChartRedraw(); 

}


bool ClosePositions()
{
  int total=PositionsTotal();
  for(int i=total-1;i>=0;i--)
    {
     if(total!=PositionsTotal())
       {
         total=PositionsTotal();
         i=total;
         continue;
       }
       
       ulong ticket=PositionGetTicket(i);
       if(ticket<=0){Print("Failed to get position total"); return false;}
       if(!PositionSelectByTicket(ticket)){Print("Failed to select position by ticket"); return false;}
       
       long magicnumber;
       if(!PositionGetInteger(POSITION_MAGIC,magicnumber)){Print("Failed to get Position magic number"); return false;}
       
       if(magicnumber==InpMagicNumber)
         {
          Print("We are closing position:");
          trade.PositionClose(ticket);
          if(trade.ResultRetcode()!=TRADE_RETCODE_DONE)
            {
              Print("Failed to close position Result: "+(string)trade.ResultRetcode()+" : "+trade.ResultRetcodeDescription());
            }else
               {
                Print("Close Successfully");
               }
         }
    }
   
   return true;

}

//count all the positions
int CountOpenPositions()
{
  int counter=0;
  
  int total=PositionsTotal();
  for(int i=total-1;i>=0;i--)
    {
     ulong ticket=PositionGetTicket(i);
     if(ticket<=0){Print("Failed to get Position Ticket"); return -1;}
     if(!PositionSelectByTicket(ticket)){Print("unable to select position by ticket"); return -1;}
     
     long magicnumber;
     if(!PositionGetInteger(POSITION_MAGIC,magicnumber)){Print("Failed to get Position Magic number"); return -1;}
     
     if(InpMagicNumber==magicnumber)
       {
         counter++;
         //Print("Position counts: ",counter);
       }
    }
    
    return counter;
}

//check inputs
bool CheckInputs()
{
  if(InpMagicNumber<=0)
     {
      Alert("Magic number <= 0");
      return false;
     }
   if(InpLotMode==LOT_MODE_FIXED && (InpLots<=0 || InpLots >10))
     {
      Alert("InpLots<=0 or InpLots > 10");
      return false;
     }
   if(InpLotMode==LOT_MODE_PCT_ACCOUNT && (InpLots<=0 || InpLots >20))
     {
      Alert("InpLots<=0 or InpLots > 20");
      return false;
     }
   if((InpLotMode==LOT_MODE_MONEY ||InpLotMode==LOT_MODE_PCT_ACCOUNT) && (InpStopLoss ==0))
     {
      Alert("Selected lotmode need a stoploss");
      return false;
     }  
    if(InpLotMode==LOT_MODE_MONEY && (InpLots<=0 || InpLots >20))
     {
      Alert("InpLots<=0 or InpLots > 5");
      return false;
     }   
   if(InpStopLoss<0 || InpStopLoss > 1000)
     {
      Alert("InpStopLoss < 0 or InpStopLoss > 1000");
      return false;
     }
   if(InpTakeProfit<0 || InpTakeProfit > 1000)
     {
      Alert("InpTakeProfit < 0 or InpTakeProfit > 1000");
      return false;
     }
   if(InpRangeClose<0 && InpStopLoss ==0)
     {
      Alert("Close time and stop loss are off");
      return false;
     }       
   if(InpRangeStart<0 || InpRangeStart >= 1440)
     {
      Alert("InpRangeStart<0 or InpRangeStart >= 1440");
      return false;
     } 
    if(InpRangeDuration<=0 || InpRangeDuration >= 1440)
     {
      Alert("InpRangeDuration<=0 or InpRangeDuration > 1");
      return false;
     } 
    if(InpRangeClose >= 1440 || (InpRangeStart+InpRangeDuration)%1440==InpRangeClose)
     {
      Alert("InpRangeClose >= 1440 or endtime is equal to close time");
      return false;
     }
     if(InpMonday+InpTuesday+InpWednesday+InpThursday+InpFriday==0)
     {
      Alert("Range is prohibited in all days of the week");
      return false;
     } 
   
  return true;
}


//calculate lots

bool CalculateLots(double slDistance, double &lots)
{
  lots=0.0;
  
  if(InpLotMode==LOT_MODE_FIXED)
    {
     lots=InpLots;
    }else
    {
     double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
     double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
     double volumestep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
     
     double riskMoney=InpLotMode==LOT_MODE_MONEY?InpLots:AccountInfoDouble(ACCOUNT_EQUITY)*InpLots*0.01;
     double moneyVolumeStep=(slDistance/tickSize)*tickValue*volumestep;
     
     lots=MathFloor(riskMoney/moneyVolumeStep)*volumestep;
        
    }
    Print("Calculated  lots: ",lots);
    //check calculated lots
    if(!CheckLots(lots)){return false;}
    
  return true;
}


//check lots
bool CheckLots(double &lots)
{
  double min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
  double max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
  double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
  
  if(lots<min)
    {
     Print("Lotsize will be set to minimum lot value lots: ",lots);
     lots=min;
    }
    if(lots>max)
    {
     Print("Lotsize will be set to maximum lot value, lots: ",lots);
     lots=max;
    }
    
    lots=(int)MathFloor(lots/step)*step;
    Print("Calculated check lots: ",lots," max | min :",max," ",min);
  return true;
}

//update Stop Loss
void UpdateStopLoss()
{
  //return if no stop loss
  if(InpStopLoss==0 || !InpStopLossTrailing){return;}
  //loop through open Positions
  int total=PositionsTotal();
  for(int i=total-1;i>=0;i--)
    {
     ulong ticket=PositionGetTicket(i);
     if(ticket<=0){Print("Failed to get Position Ticket"); return ;}
     if(!PositionSelectByTicket(ticket)){Print("unable to select position by ticket"); return ;}
     
     long magicnumber;
     if(!PositionGetInteger(POSITION_MAGIC,magicnumber)){Print("Failed to get Position Magic number"); return ;}
     
     if(InpMagicNumber==magicnumber)
       {
         //type of position
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type)){Print("Failed to get Position type"); return;}
         
         //get current sl and tp
         double currSL,currTP;
         if(!PositionGetDouble(POSITION_SL,currSL)){Print("Failed to get Position sL"); return;}
         if(!PositionGetDouble(POSITION_TP,currTP)){Print("Failed to get Position TP"); return;}
         
         //calculate new Stop loss
         double currPrice=type==POSITION_TYPE_BUY?lastTick.bid:lastTick.ask;
         int n =type==POSITION_TYPE_BUY?1:-1;
         
         double newSL=NormalizeDouble(currPrice-((range.high-range.low) * InpStopLoss*0.01*n),_Digits);
         
         //check if new stoploss is closer to current price than the existing stop loss
         if((newSL*n) < (currSL*n) || NormalizeDouble(MathAbs(newSL-currSL),_Digits)<_Point)
           {
            //Print("No new Stop loss needed");
            continue;
           }
           
         //check for stop level
         long level=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL); 
         if(level!=0 && MathAbs(currPrice-newSL)<=level*_Point)
           {
            Print("New Stop loss inside stop level");
            continue;
           }  
           
           //modify trade
           if(!trade.PositionModify(ticket,newSL,currTP))
             {
              Print("Failed to Modify Position: ",(string)ticket," currSl: ",(string)currSL," currTP: ",(string)currTP);
              return;
             }
           
       }
    }
    
}