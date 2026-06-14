//+------------------------------------------------------------------+
//|                                                rangebreakout.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#property script_show_inputs
#include <Canvas/Canvas.mqh>
//+------------------------------------------------------------------+
//| graph code                                                       |
//+------------------------------------------------------------------+
input string BotToken = "8685310495:AAGbmwqgdN81vrifE8ImmIzVsor9iDvr4Tk";
input string ChatID   = "1322296326";
input int   TeleCycleSeconds=4;
long last_update_id = 0;



double running_profit = 0;
double cumulative_profit_array[];

double peak_equity = 0;
double peak_dd = 0;


double min_profit = 0;
double max_profit = 0;
bool dashboard_visible = true;

int W = 650;
int H = 300;

CCanvas canvas;
string CANVAS_NAME = "DASH_CANVAS";
input double StartingCapital=100;
input double AllowedDD=21; //AllowedDD in %
input double PercentReduce=0.5;
input double FinishLine=108050;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

enum TRIGGER_MODE
  {
   ONE_SIDED=1,
   TWO_SIDED=2
  };
input bool EnableNews=false; //Disable News ?  
input TRIGGER_MODE InpTriggerMode=ONE_SIDED;
input double DailyProfitTarget=20; //Daily Profit Target in %
input double DailyLossStop=-10; //Daily Stop in %
input bool Reversalbreakout=false;


double profitClosed;
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

input double InpLots=0.01;       //lots / money/ %

input int InpTakeProfit=0;       //TakeProfit in % of the range (0=off)
input int InpStopLoss=90;        //stop loss in % of the range  (0=off)
input bool InpStopLossTrailing=false; // Trailing stop loss
input group "Range Setting"
input int InpRangeStart=90;     // range start time in minutes
input int InpRangeDuration=270;   // range duration in minutes
input int InpRangeClose=1200 ;    //range close time in minutes 


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
MqlTick  lastTick;  
CTrade trade;

bool enableEA=true;
double newPercentLot;
double peak_dd_percent=0.0;
//chat variabe

double riskincrement=0;
double profitpercenttarget=0;
double losspercentlimit=0;
double maxdrawdown=0;
double startCapital=0;
double finishProfit=0;
string help="ChatBot "+_Symbol+" EA started \n Account: "+AccountInfoString(ACCOUNT_NAME)+
                          "\n MagicNumber:"+InpMagicNumber+
                          "\nServer: " + AccountInfoString(ACCOUNT_SERVER)+
                           ".\n Command:\n balance"+
                           "\n equity"+
                           "\n screenshot"+
                           " \n help "+
                           "\n status" + IntegerToString(InpMagicNumber)+
                           "\n disable"+InpMagicNumber+
                           "\n closeposition"+InpMagicNumber+
                           "\n newPercentLot"+InpMagicNumber+
                           "\n riskincrement"+InpMagicNumber+
                           "\n profitpercenttarget"+InpMagicNumber+
                           "\n losspercentlimit"+InpMagicNumber+
                           "\n maxdrawdown"+InpMagicNumber+
                           "\n startCapital"+InpMagicNumber+
                           "\n finishProfit"+InpMagicNumber+    
                            "\n enable"+InpMagicNumber;



int OnInit()
  {
      EventSetTimer(TeleCycleSeconds);
      //string account_name = AccountInfoString(ACCOUNT_NAME);

      //Print("Account Name: ", account_name);
      
      SendTelegramMessage(help);
      if(!CheckInputs())
      {
          return INIT_PARAMETERS_INCORRECT;
      }
         
       if(_UninitReason==REASON_PARAMETERS && CountOpenPositions()==0)
      {
        CalculateRange();
      }
      
       
      //intialize input for chat
       newPercentLot=InpLots;
       riskincrement=PercentReduce;
       profitpercenttarget=DailyProfitTarget;
       losspercentlimit=DailyLossStop;
       maxdrawdown=AllowedDD;
       startCapital=StartingCapital;
       finishProfit=FinishLine;
      
      trade.SetExpertMagicNumber(InpMagicNumber);
      
     //Draw Objects again when change in TimeFrame 
      DrawObjects(); 
      //
       profitClosed=CalculateDailyProfitClosed();
       
       //graph code
       
   
   canvas.CreateBitmapLabel(
      0, 0,
      "DASH",
      W,
      H,
      COLOR_FORMAT_ARGB_NORMALIZE
   );
   
  
   BuildHistory();

   Draw();
       //graph code
         
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
     EventKillTimer();
     canvas.Destroy();
      ObjectsDeleteAll(0, "DASH");
      ChartRedraw();
   
  }
 
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   
   if(!enableEA)
     {
       
       return;
     }
   
   double accountBalance=AccountInfoDouble(ACCOUNT_BALANCE);
     double accountEquity=AccountInfoDouble(ACCOUNT_EQUITY);
     double profitOpen=accountEquity-accountBalance;
     double profitDay=profitOpen+profitClosed;
     
     if(EnableNews)
       {
         if(isNewsEventAhead())
          {
           Print("Danger news ahead!!!!....");
           trade.PositionClose(_Symbol);
          }
       }
     
     
     
     Comment(" Profit Open: ",DoubleToString(profitOpen,2),
             " Profit Closed: ",DoubleToString(profitClosed,2),
             " Profit for the  Day: ",DoubleToString(profitDay,2),
             " Target Profit: ",DoubleToString((profitpercenttarget*0.01*AccountInfoDouble(ACCOUNT_BALANCE)),2),
             " Stop Loss : ",DoubleToString((losspercentlimit*0.01*AccountInfoDouble(ACCOUNT_BALANCE)),2));
             
    if(profitDay >(profitpercenttarget*0.01*AccountInfoDouble(ACCOUNT_BALANCE)) || profitDay <(losspercentlimit*0.01*AccountInfoDouble(ACCOUNT_BALANCE)) || AccountInfoDouble(ACCOUNT_EQUITY)>=finishProfit || !enableEA)
      {
        for(int i=PositionsTotal()-1;i>=0;i--)
          {
            ulong posTicket=PositionGetTicket(i);
            trade.PositionClose(posTicket);
          }
      } 
   
   
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
     || range.end_time==0
     || (range.end_time!=0 && lastTick.time > range.end_time && !range.f_entry))
     && CountOpenPositions()==0)
     {
      Print("Positons count: ",CountOpenPositions());
      //Print("Hello");
      CalculateRange();
     
     }
     //Print("open positions: ",CountOpenPositions());
     //check break out
    CreatePendingOrder(); 
    
    //update StopTrailing
    if(InpStopLossTrailing)
      {
       UpdateStopLoss();
      }
   
  }
//+------------------------------------------------------------------+

//Creat Pending Orders
void CreatePendingOrder()
{
  if(lastTick.time>=range.end_time && range.end_time >0 && range.f_entry)
    {
      //create pending orders for high breakout
      if(!range.f_high_breakout)
        {
          range.f_high_breakout=true;
          
          //open a Position
          
          //calculate stoploss and Take profit
          //calculate lots later
            double rangeSize = range.high - range.low;

            double entry = range.high;
            double sl, tp;
            
            //calculate lots later
            double lots;
            
            
            //create order
            if(Reversalbreakout)
            {
               // SELL LIMIT (reversal from top)
               sl = InpStopLoss == 0 ? 0 : NormalizeDouble(entry + rangeSize * InpStopLoss * 0.01, _Digits); // ABOVE
               tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(entry - rangeSize * InpTakeProfit * 0.01, _Digits); // BELOW
            
               if(!CalculateLots(sl - entry, lots)) return;
            
               trade.SellLimit(lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, range.close_time, "range reversal sell");
            }
            else
            {
               // BUY STOP (breakout)
               sl = InpStopLoss == 0 ? 0 : NormalizeDouble(entry - rangeSize * InpStopLoss * 0.01, _Digits); // BELOW
               tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(entry + rangeSize * InpTakeProfit * 0.01, _Digits); // ABOVE
            
               if(!CalculateLots(entry - sl, lots)) return;
            
               trade.BuyStop(lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, range.close_time, "range breakout buy");
            }
          
        }
        
       //create a Sell Stop Order
      if(!range.f_low_breakout)
        {
          range.f_low_breakout=true;
          
            double rangeSize = range.high - range.low;
            double entry = range.low;
            double sl, tp;
            double lots;
            
            if(Reversalbreakout)
            {
               // BUY LIMIT (reversal from bottom)
               sl = InpStopLoss == 0 ? 0 : NormalizeDouble(entry - rangeSize * InpStopLoss * 0.01, _Digits); // BELOW
               tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(entry + rangeSize * InpTakeProfit * 0.01, _Digits); // ABOVE
            
               if(!CalculateLots(entry - sl, lots)) return;
            
               trade.BuyLimit(lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, range.close_time, "range reversal buy");
            }
            else
            {
               // SELL STOP (breakout)
               sl = InpStopLoss == 0 ? 0 : NormalizeDouble(entry + rangeSize * InpStopLoss * 0.01, _Digits); // ABOVE
               tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(entry - rangeSize * InpTakeProfit * 0.01, _Digits); // BELOW
            
               if(!CalculateLots(sl - entry, lots)) return;
            
               trade.SellStop(lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, range.close_time, "range breakout sell");
            }
         
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
     lots=newPercentLot;
    }else
    {
     double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
     double tickValue=_Symbol=="XAUUSD"?SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE)*100:SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
     double volumestep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
     
     double riskMoney=InpLotMode==LOT_MODE_MONEY?newPercentLot:AccountInfoDouble(ACCOUNT_EQUITY)*newPercentLot*0.01;
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


void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
     if(trans.type==TRADE_TRANSACTION_DEAL_ADD)
       {
         profitClosed=CalculateDailyProfitClosed();
       }
     // When a new deal is created
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        ulong posTicket = trans.position;
        
        // Load the position to check magic number
        if(PositionSelectByTicket(posTicket))
        {
            int posMagic = (int)PositionGetInteger(POSITION_MAGIC);

            // Only react to THIS EA's position
            if(posMagic == InpMagicNumber)
            {
                Print("My EA opened a position!");
                if(InpTriggerMode==ONE_SIDED)
                  {
                    ClosePendingOrdersByMagic(InpMagicNumber);
                  }
                
                // Now delete all pending orders from this EA
               // DeleteMyPendingOrders();
            }else{
             Print("anthor guy open position");
            }
        }
    } 
    //graph code
    // 1. Only deal events
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong mydeal = trans.deal;
   if(mydeal == 0)
      return;

   // 2. Load history cache
   HistorySelect(TimeCurrent() - (86400 * 30), TimeCurrent());

   // FIX: You MUST select the deal first before calling HistoryDealGetInteger!
   if(!HistoryDealSelect(mydeal))
      return;

   // 3. Only closing deals (Handles complete OUT and partial INOUT closing reversals)
   long entryType = HistoryDealGetInteger(mydeal, DEAL_ENTRY);
   if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_INOUT)
      return;

   // 4. Extract Magic Number with Cascading Backups
   long magicNo = HistoryDealGetInteger(mydeal, DEAL_MAGIC);
   
   // Fallback A: Trace the history of the specific position lifecycle to find the opening deal
   if(magicNo == 0 && trans.position > 0)
   {
      if(HistorySelectByPosition(trans.position))
      {
         int totalDeals = HistoryDealsTotal();
         for(int i = 0; i < totalDeals; i++)
         {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
            {
               magicNo = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
               break;
            }
         }
      }
   }
   
   // Fallback B: Look directly at the order ticket that executed this closure
   if(magicNo == 0)
   {
      ulong closeOrderTicket = (ulong)HistoryDealGetInteger(mydeal, DEAL_ORDER);
      if(HistoryOrderSelect(closeOrderTicket))
      {
         magicNo = HistoryOrderGetInteger(closeOrderTicket, ORDER_MAGIC);
      }
   }

   // Fallback C: Scan history for the very first order setup using Position ID
   if(magicNo == 0 && trans.position > 0)
   {
      ulong positionID = trans.position;
      if(HistorySelectByPosition(positionID))
      {
         int totalOrders = HistoryOrdersTotal();
         for(int i = 0; i < totalOrders; i++)
         {
            ulong orderTicket = HistoryOrderGetTicket(i);
            if(HistoryOrderGetInteger(orderTicket, ORDER_POSITION_ID) == (long)positionID)
            {
               magicNo = HistoryOrderGetInteger(orderTicket, ORDER_MAGIC);
               if(magicNo != 0) break;
            }
         }
      }
   }
   
   // 5. Execute calculations if the recovered Magic matches your EA input
   Print("Hello Processed Magic: ", magicNo);
   
   if(magicNo == InpMagicNumber)
   {
      Print("ontrade MagicNo: ", magicNo);
      double myprofit = HistoryDealGetDouble(mydeal, DEAL_PROFIT);
      Print("ontrade Profit: ", myprofit);

      // update running state
      running_profit += myprofit;
   
      // update bounds (NO rescan loop)
      if(running_profit > max_profit) max_profit = running_profit;
      if(running_profit < min_profit) min_profit = running_profit;
   
      // append new point
      int s = ArraySize(cumulative_profit_array);
      ArrayResize(cumulative_profit_array, s + 1);
      cumulative_profit_array[s] = running_profit;
   
      // 1. update peak equity
      if(running_profit > peak_equity){
      
         peak_equity = running_profit;
         
         newPercentLot=newPercentLot+riskincrement;
         Print("######## Risk increased automatically by ######",newPercentLot);
         SendTelegramMessage(_Symbol+" New peak Equity hit....MagicNo: "+InpMagicNumber); 
         }
         
      
      // 2. compute drawdown
      double current_dd = peak_equity - running_profit;
      
      
      // 3. track worst drawdown
      if(current_dd > peak_dd){
         peak_dd = current_dd;
         
         SendTelegramMessage(_Symbol+"New peak DD hit....MagicNo: "+InpMagicNumber);
         
         newPercentLot=newPercentLot-riskincrement;
         
         Print("######## Risk Decreased automatically by ######",newPercentLot);
          
         }
      //if(peak_equity>0)
      {   
         peak_dd_percent = (peak_dd/(startCapital+peak_equity))*100;
      } 
      Print("peak_equity: ",peak_equity," peak_dd: ",peak_dd," ratio of peakdd: ",(peak_dd/(startCapital+peak_equity)));
       
      if(peak_dd_percent >maxdrawdown)
        {
          enableEA=false;
          ClosePositions();
          Print("========EA draw Limit hit========");
        }    
        
      Draw();              // build chart
      ChartRedraw();       // force refresh
         
      Print("Draw again ", running_profit, " profit: ", myprofit);
   }
    //graph code 
   
  }

void ClosePendingOrdersByMagic(int magicNumber)
{
   // iterate backwards so deleting doesn't break indexing
   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
   {
       ulong ticket = OrderGetTicket(i); 
      // select order by position from the pool of current (open & pending) orders
      if(OrderSelect(ticket))
      {
         
         int type = (int)OrderGetInteger(ORDER_TYPE);
         int magic = (int)OrderGetInteger(ORDER_MAGIC);

         // target pending order types only
         if(type == ORDER_TYPE_BUY_LIMIT  ||
            type == ORDER_TYPE_SELL_LIMIT ||
            type == ORDER_TYPE_BUY_STOP   ||
            type == ORDER_TYPE_SELL_STOP  ||
            type == ORDER_TYPE_BUY_STOP_LIMIT ||
            type == ORDER_TYPE_SELL_STOP_LIMIT)
         {
            if(magic == magicNumber)
            {
               Print("we are in here");
               // attempt to delete/cancel the pending order
               if(!trade.OrderDelete(ticket))
               {
                  PrintFormat("Failed to delete pending order #%I64u (magic=%d). Error=%d",
                              ticket, magic, GetLastError());
               }
               else
               {
                  PrintFormat("Deleted pending order #%I64u (magic=%d).", ticket, magic);
               }
            }
         }
      }
      else
      {
         // If OrderSelect fails, print error (helps debugging)
         PrintFormat("OrderSelect(%d) failed, Error=%d", i, GetLastError());
      }
   }
}  
  
  
double CalculateDailyProfitClosed()
{
   double profit=0;
   MqlDateTime dt;
   TimeTradeServer(dt);
   dt.hour=0;
   dt.min=0;
   dt.sec=0;
   
   datetime timeDaystart=StructToTime(dt);
   datetime timeNow = TimeTradeServer();
   
   HistorySelect(timeDaystart,timeNow+100);
   for(int i=HistoryDealsTotal()-1;i>=0;i--)
     {
        ulong dealTicket = HistoryDealGetTicket(i);
        //double dealProfit=HistoryDealGetDouble(dealTicket,DEAL_PROFIT);
        
        int dealType = (int)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        if (dealType==DEAL_ENTRY_OUT)
         {
            
         
        
        //Print("Deal Ticket: ", dealTicket," profit: ",dealProfit);
        
       
         string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
         double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         double mydealprofit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         int type = (int)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         ulong order = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
         double commission= HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         
         //Print("DealTicket: ", dealTicket,", Order: ", order,", Symbol: ", symbol,", Profit: ", profit,", commission ",commission);
               
            //calculate profit
              profit+=mydealprofit+commission; 
             //Print("Profit: ",DoubleToString(profit+=mydealprofit,2));  
               
            }   
            
         }
   return profit;
}



bool isNewsEventAhead()
{
   MqlCalendarValue value[];
     datetime startTime=iTime(_Symbol,PERIOD_CURRENT,0);
     datetime endTime=startTime+PeriodSeconds(PERIOD_D1);
     CalendarValueHistory(value,startTime,endTime,NULL,NULL);
     
     
     
     for(int i=0;i<ArraySize(value);i++)
       {
         MqlCalendarEvent event;
         CalendarEventById(value[i].event_id,event);
         MqlCalendarCountry country;
         CalendarCountryById(event.country_id,country);
         
         string mysymbol=_Symbol;
         if(StringFind(mysymbol,country.currency)<0)continue;
         if(event.importance==CALENDAR_IMPORTANCE_LOW)continue;
         if(event.importance==CALENDAR_IMPORTANCE_NONE)continue;
         
         if(TimeCurrent()>=value[i].time-15*PeriodSeconds(PERIOD_M1) && TimeCurrent()<value[i].time+15*PeriodSeconds(PERIOD_M1))
           {
            Print("News Ahead !!!!!!!");
            return true;
           }
         Print(event.name," => ", value[i].actual_value/1000000);
       }
       
       return false;
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_KEYDOWN)
   {
      if(lparam == 'D') // press D
      {
         dashboard_visible = !dashboard_visible;

         if(dashboard_visible){
            canvas.Resize(W, H);
            canvas.Erase(ColorToARGB(clrBlack));
            Draw();
         }   
         else{
            canvas.Resize(1, 1); // effectively invisible
         }   
        Print("Toggle: ",dashboard_visible);    
      }
   }
}



void Draw()
{
   canvas.Erase(ColorToARGB(clrBlack));

   int n = ArraySize(cumulative_profit_array);

   double chart_range  = max_profit - min_profit;
   if(chart_range  == 0) chart_range  = 1;

   if(n >= 2)
   {
      int prev_x = 0;
      int prev_y = 0;

      for(int i = 0; i < n; i++)
      {
         int x = (int)((double)i / (n - 1) * W);

         double value = cumulative_profit_array[i];

         int y = H - (int)((value - min_profit) / chart_range  * (H-20))-20;
         
         if(i > 0)
            canvas.Line(prev_x, prev_y, x, y, ColorToARGB(clrWhite));
            

         prev_x = x;
         prev_y = y;
      }
   }

   // ✅ ALWAYS draw text (even if n < 2)
   canvas.FontSet("Consolas", 14);

   string text =
      _Symbol+" Click 'D' to hide/show | PnL: " +
      DoubleToString(startCapital+running_profit, 2)+" peak_equity: "+DoubleToString(startCapital+peak_equity,2)+" peak_dd: -"+DoubleToString(peak_dd,2);
   Print("peak_equity: ",peak_dd);
   canvas.TextOut(30, 15, text, ColorToARGB(clrWhite));
   string alloweddd="Max Allowed DD: -"+DoubleToString(maxdrawdown,1)+"% currentDD %:- "+DoubleToString(peak_dd_percent,2)+" EnableEA: "+enableEA+" Risk %:"+DoubleToString(newPercentLot,2);
   canvas.TextOut(30, 30, alloweddd, ColorToARGB(clrWhite));
   string accountName="Account Name: "+AccountInfoString(ACCOUNT_NAME);
   canvas.TextOut(30, 45, accountName, ColorToARGB(clrWhite));
   
   int ddline = H - (int)((peak_equity-min_profit) / chart_range * (H - 20)) - 20;
   Print("peak_equity ",peak_equity," min_profit: ",min_profit," max_profit: ",max_profit);
   //canvas.Line(0, ddline, W, ddline, ColorToARGB(clrBeige));
   canvas.Update(true);
}



bool SendTelegramMessage(string text)
{
   string url=
      "https://api.telegram.org/bot"+
      BotToken+
      "/sendMessage";

   string data=
      "chat_id="+ChatID+
      "&text="+text;

   char post[];
   char result[];

   StringToCharArray(data,post);

   string headers=
      "Content-Type: application/x-www-form-urlencoded\r\n";

   string response_headers;

   ResetLastError();

   int res=WebRequest(
      "POST",
      url,
      headers,
      5000,
      post,
      result,
      response_headers
   );

   if(res==-1)
   {
      Print("Error: ",GetLastError());
      return(false);
   }

   Print("Telegram response: ",CharArrayToString(result));

   return(true);
}
void OnTimer()
{
   CheckTelegram();
}

void CheckTelegram()
{
   string url =
      "https://api.telegram.org/bot" +
      BotToken +
      "/getUpdates?offset=" +
      IntegerToString((int)(last_update_id + 1));

   uchar data[];
   uchar result[];
   string response_headers;

   ResetLastError();

   int res = WebRequest(
      "GET",
      url,
      "",
      5000,
      data,
      result,
      response_headers
   );

   if(res == -1)
   {
      Print("WebRequest Error: ", GetLastError());
      return;
   }

   string json = CharArrayToString(result);

   //Print("Telegram JSON:");
   //Print(json);

   ProcessMessage(json);
}
void ProcessMessage(string json)
{
   // Find update_id
   int pos = StringFind(json, "\"update_id\":");

   if(pos >= 0)
   {
      pos += StringLen("\"update_id\":");

      string update_str = "";

      while(pos < StringLen(json))
      {
         ushort ch = StringGetCharacter(json, pos);

         if(ch >= '0' && ch <= '9')
            update_str += CharToString((uchar)ch);
         else
            break;

         pos++;
      }

      if(update_str != "")
         last_update_id = (long)StringToInteger(update_str);
   }

   // Process commands
   if(StringFind(json, "\"text\":\"balance\"") >= 0)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);

      SendTelegramMessage(
         AccountInfoString(ACCOUNT_NAME)+" Balance = " +
         DoubleToString(balance, 2)
      );
   }

   if(StringFind(json, "\"text\":\"equity\"") >= 0)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);

      SendTelegramMessage(
         AccountInfoString(ACCOUNT_NAME)+" Equity = " +
         DoubleToString(equity, 2)
      );
   }
   string cmd = "status" + IntegerToString(InpMagicNumber);

   if(StringFind(json, cmd) >= 0)
   {
      string msg =
         "EA Settings\n"
         "enableEA: " + (enableEA ? "true" : "false") + "\n"
         "newPercentLot: " + DoubleToString(newPercentLot, 2) + "\n"
         "running_profit: " + DoubleToString(running_profit, 2) + "\n"
         "peak_equity: " + DoubleToString(peak_equity, 2) + "\n"
         "peak_dd: " + DoubleToString(peak_dd, 2) + "\n"
         "peak_dd_percent: " + DoubleToString(peak_dd_percent, 2) + "\n"
         "riskincrement: " + DoubleToString(riskincrement, 2) + "\n"
         "profitpercenttarget: " + DoubleToString(profitpercenttarget, 2) + "\n"
         "losspercentlimit: " + DoubleToString(losspercentlimit, 2) + "\n"
         "maxdrawdown: " + DoubleToString(maxdrawdown, 2) + "\n"
         "startCapital: " + DoubleToString(startCapital, 2) + "\n"
         "finishProfit: " + DoubleToString(finishProfit, 2);
   
      SendTelegramMessage(msg);
   }
   if(StringFind(json, "\"text\":\"screenshot\"") >= 0)
   {
      TakeScreenshot();
      SendTelegramMessage(AccountInfoString(ACCOUNT_NAME)+" Screenshot captured.");
      SendPhotoToTelegram("chart.png");
      
   }
   if(StringFind(json, "\"text\":\"help\"") >= 0)
   {
      string account_name = AccountInfoString(ACCOUNT_NAME);
      SendTelegramMessage(help);
      
   }
   if(StringFind(json, "\"text\":\"disable"+IntegerToString(InpMagicNumber)+"\"") >= 0)
   {
       enableEA=false;
      SendTelegramMessage("EA disabled successfully");
      Draw();
   }
   if(StringFind(json, "\"text\":\"enable"+IntegerToString(InpMagicNumber)+"\"") >= 0)
   {
       enableEA=true;
      SendTelegramMessage("EA enabled successfully");
      Draw();
   }
   if(StringFind(json, "\"text\":\"closeposition"+IntegerToString(InpMagicNumber)+"\"") >= 0)
   {
       ClosePositions();
      SendTelegramMessage(_Symbol+"Position Closed successfully No position ");
      Draw();
   }
  
       
    string magic = IntegerToString(InpMagicNumber);

       UpdateDoubleSetting(
         json,
         "finishProfit" + magic,
         "finishProfit",
         finishProfit
      );
      
      UpdateDoubleSetting(
         json,
         "newPercentLot" + magic,
         "newPercentLot",
         newPercentLot
      );
      
      UpdateDoubleSetting(
         json,
         "riskincrement" + magic,
         "riskincrement",
         riskincrement
      );
      
      UpdateDoubleSetting(
         json,
         "profitpercenttarget" + magic,
         "profitpercenttarget",
         profitpercenttarget
      );
      
      UpdateDoubleSetting(
         json,
         "losspercentlimit" + magic,
         "losspercentlimit",
         losspercentlimit
      );
      
      UpdateDoubleSetting(
         json,
         "maxdrawdown" + magic,
         "maxdrawdown",
         maxdrawdown
      );
      
      UpdateDoubleSetting(
         json,
         "startCapital" + magic,
         "startCapital",
         startCapital
      ); 
   
        
  
}
bool UpdateDoubleSetting(string json,
                         string command,
                         string name,
                         double &variable)
   {
      if(StringFind(json, command + "=") < 0)
         return false;
   
      string value = ExtractCommandValue(json, command);
   
      if(value == "")
         return false;
   
      variable = StringToDouble(value);
   
      SendTelegramMessage(
         _Symbol + " " + name +
         " set to " +
         DoubleToString(variable, 2)
      );
   
      Draw();
   
      return true;
   }
   
   string ExtractCommandValue(string text, string command)
   {
      int pos = StringFind(text, command + "=");
   
      if(pos < 0)
         return "";
   
      int start = pos + StringLen(command) + 1;
   
      int end = StringFind(text, "\"", start);
   
      if(end < 0)
         return "";
   
      return StringSubstr(text, start, end - start);
   }
bool TakeScreenshot()
{

   long chart_id = ChartFirst();

   while(chart_id != -1)
   {
      Print("ID=", chart_id,
            " Symbol=", ChartSymbol(chart_id));
   
      chart_id = ChartNext(chart_id);
   }

   string file_name = "chart.png";
   
   long my_id = 134257605198610781;

   bool ok = ChartScreenShot(
      0,          // current chart
      file_name,
      1280,
      720
   );

   if(ok)
      Print("Screenshot saved");
   else
      Print("Screenshot failed");

   return ok;
}

bool SendPhotoToTelegram(string file_name)
{
   // Read image
   int handle = FileOpen(file_name, FILE_READ | FILE_BIN);

   if(handle == INVALID_HANDLE)
   {
      Print("Cannot open file: ", file_name);
      return false;
   }

   int file_size = (int)FileSize(handle);

   uchar image[];
   ArrayResize(image, file_size);

   FileReadArray(handle, image);
   FileClose(handle);

   string boundary = "----MQL5TelegramBoundary";

   string part1 =
      "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n" +
      ChatID + "\r\n" +
      "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"photo\"; filename=\"chart.png\"\r\n" +
      "Content-Type: image/png\r\n\r\n";

   string part2 =
      "\r\n--" + boundary + "--\r\n";

   uchar body[];

   uchar p1[];
   uchar p2[];

   StringToCharArray(part1, p1);
   StringToCharArray(part2, p2);

   int total =
      ArraySize(p1)-1 +
      ArraySize(image) +
      ArraySize(p2)-1;

   ArrayResize(body, total);

   int pos = 0;

   // Part 1
   for(int i=0; i<ArraySize(p1)-1; i++)
      body[pos++] = p1[i];

   // Image
   for(int i=0; i<ArraySize(image); i++)
      body[pos++] = image[i];

   // Part 2
   for(int i=0; i<ArraySize(p2)-1; i++)
      body[pos++] = p2[i];

   string headers =
      "Content-Type: multipart/form-data; boundary=" +
      boundary + "\r\n";

   uchar result[];
   string response_headers;

   string url =
      "https://api.telegram.org/bot" +
      BotToken +
      "/sendPhoto";

   ResetLastError();

   int res = WebRequest(
      "POST",
      url,
      headers,
      10000,
      body,
      result,
      response_headers
   );

   if(res == -1)
   {
      Print("WebRequest Error: ", GetLastError());
      return false;
   }

   string response = CharArrayToString(result);

   Print("Telegram Response:");
   Print(response);

   return true;
}
void BuildHistory()
{
    // RESET STATE
   running_profit = 0;
   peak_equity = 0;
   peak_dd = 0;

   min_profit = 0;
   max_profit = 0;

   ArrayFree(cumulative_profit_array);
   HistorySelect(0, TimeCurrent());

   int total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);

      if((int)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      
      ulong magicNo=HistoryDealGetInteger(deal,DEAL_MAGIC);
      
      if(magicNo==InpMagicNumber){
      Print("MagicNo: ",magicNo);
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);

      running_profit += profit;

      // update bounds (NO rescaling loop later)
      if(running_profit > max_profit) max_profit = running_profit;
      if(running_profit < min_profit) min_profit = running_profit;

      // store point
      int s = ArraySize(cumulative_profit_array);
      ArrayResize(cumulative_profit_array, s + 1);
      cumulative_profit_array[s] = running_profit;
      
      // 1. update peak equity
      if(running_profit > peak_equity)
         peak_equity = running_profit;
      
      // 2. compute drawdown
       double current_dd = peak_equity - running_profit;
      
      // 3. track worst drawdown
      if(current_dd > peak_dd)
         peak_dd = current_dd;  
       }  
   }
}