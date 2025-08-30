#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//|includes                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//|inputs                                                            |
//+------------------------------------------------------------------+
static input long       InpMagicNumber=988998;// Magic Number
static input double     InpLots=0.01; // LotSize
input  int              InpBars=20;   // bars for High/Low  
input  int              InpStopLoss=200;  // Stop Loss in Points 
input  int              InpTakeProfit=0;  // Take Profit in Points (0==off)
input  int              InpIndexFilter=10; // Index Filer % (0==off)
input  int              InpSizeFilter=50; //The height of the range
input  bool             InpTrailingStop=true; // Tailing Stop Loss

//+------------------------------------------------------------------+
//|Global Variables                                                  |
//+------------------------------------------------------------------+
double high=0; // Highest Price of the last N bars
double low=0;  //Lowest Price of the Last N bars
int highIdx=0; // index of the Highest bar
int lowIdx=0;  // index of the Lowest bar
MqlTick currentTick, previousTick;
CTrade trade;


int OnInit()
  {
   //check for userInputs
   //if(!CheckInputs()){ return INIT_PARAMETERS_INCORRECT; }
   trade.SetExpertMagicNumber(InpMagicNumber);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
  ObjectDelete(NULL,"high");
  ObjectDelete(NULL,"low");
  ObjectDelete(NULL,"text");
  ObjectDelete(NULL,"indexFilter");
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  
   //check for new Bar
   if(!IsNewBar()){return;} 
  
   //get Current Tick
   previousTick=currentTick;
   if(!SymbolInfoTick(_Symbol,currentTick)){Print("Failed to get current Tick"); return;}
   
   //count buy and sell position
   
   int cntBuy=0,cntSell=0;
   if(!Countpositions(cntBuy,cntSell)){return;}
   
   //check for buy Signal
   if(cntBuy==0 && high!=0 && previousTick.ask <high && currentTick.ask>=high && CheckIndexFilter(highIdx) && CheckSizeFilter())
   {
      Print("Open Buy Position");
      //calculate StopLoss
      double sl=InpStopLoss==0?0:currentTick.bid-InpStopLoss*_Point;
      double tp=InpTakeProfit==0?0:currentTick.bid+InpTakeProfit*_Point;
      if(!NormalizePrice(sl)){return;}
      if(!NormalizePrice(tp)){return;}
      trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLots,currentTick.ask,sl,tp,"HighLow Buy");
   }
   
   if(cntSell==0 && low!=0 && previousTick.bid >low && currentTick.bid<=low  && CheckIndexFilter(lowIdx) && CheckSizeFilter())
   {
      Print("Open Sell Position");
      
      double sl=InpStopLoss==0?0:currentTick.ask+InpStopLoss*_Point;
      double tp=InpTakeProfit==0?0:currentTick.ask-InpTakeProfit*_Point;
      if(!NormalizePrice(sl)){return;}
      if(!NormalizePrice(tp)){return;}
      trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLots,currentTick.bid,sl,tp,"HighLow Sell");
   }
   
   if(InpTrailingStop && InpStopLoss>0)
     {
       UpdateStopLoss(InpStopLoss);
     }
   
   //calculate High and Low
   highIdx=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpBars,1);
   high=iHigh(_Symbol,PERIOD_CURRENT,highIdx);
   lowIdx=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,InpBars,1);
   low=iLow(_Symbol,PERIOD_CURRENT,lowIdx);
   DrawObjects();
  }
//+------------------------------------------------------------------+
//|Custom Funtions                                                    |
//+------------------------------------------------------------------+
//check User Inputs
bool CheckInputs()
{
  if(InpMagicNumber<=0)
    {
      Alert("Wrong Input:MagicNumber  <=0");
      return false;
    }
    if(InpLots<=0)
    {
      Alert("Wrong Input:Lots <=0");
      return false;
    }
    if(InpBars<=0)
    {
      Alert("Wrong Input:Bars <=0");
      return false;
    }
    if(InpStopLoss<=0)
    {
      Alert("Wrong Input:StopLoss <=0");
      return false;
    }
    if(InpTakeProfit<=0)
    {
      Alert("Wrong Input:TakeProfit <=0");
      return false;
    }
    
  return true;
}

//DrawObject
void DrawObjects()
{
    string trendlineName = "high"; // Name of the trendline
    datetime time1 = iTime(NULL, 0, InpBars); // Start time for the trendline
    double price1 = high; // Start price for the trendline
    datetime time2 = iTime(NULL, 0, 1);  // End time for the trendline
    double price2 = high;  // End price for the trendline

    // Create the High trendline object
    if (ObjectCreate(0, trendlineName, OBJ_TREND, 0, time1, price1, time2, price2))
    {
        // Set line color
        ObjectSetInteger(0, trendlineName, OBJPROP_COLOR,CheckIndexFilter(highIdx) && CheckSizeFilter()?clrBlue:clrBeige);

        // Set line width
        ObjectSetInteger(0, trendlineName, OBJPROP_WIDTH, 2);

        // Set style
        ObjectSetInteger(0, trendlineName, OBJPROP_STYLE, STYLE_SOLID);

        //Print("Trendline created successfully!");
    }
    else
    {
        Print("Failed to create trendline.");
    }
    
    string trendlineName1 = "low"; // Name of the trendline
    double price3 = low; // Start price for the trendline
    
    // Create the Low trendline object
    if (ObjectCreate(0, trendlineName1, OBJ_TREND, 0, time1, price3, time2, price3))
    {
        // Set line color
        ObjectSetInteger(0, trendlineName1, OBJPROP_COLOR, CheckIndexFilter(lowIdx)&& CheckSizeFilter()?clrBlue:clrBeige);

        // Set line width
        ObjectSetInteger(0, trendlineName1, OBJPROP_WIDTH, 2);

        // Set style
        ObjectSetInteger(0, trendlineName1, OBJPROP_STYLE, STYLE_SOLID);

        //Print("Trendline created successfully!");
    }
    else
    {
        Print("Failed to create trendline.");
    }
}

bool CheckIndexFilter(int index)
{                                 //right                                     //left         
  if(InpIndexFilter>0 && (index<=round(InpBars*InpIndexFilter*0.01) || index >InpBars-round(InpBars*InpIndexFilter*0.01)))
    {
      Print("Index:",index,"calculated right: ",round(InpBars*InpIndexFilter*0.01)," Left: ",InpBars-round(InpBars*InpIndexFilter*0.01));
      return false;
    }
   return true;
}

//Normalize Price Function
bool NormalizePrice(double &price)
{
  double tickSize=0;
  if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,tickSize))
    {
     Print("Failed to get Tick Size");
     return false;
    }
    price=NormalizeDouble(MathRound(price/tickSize)*tickSize,_Digits);
    return true;
}


bool Countpositions(int &cntBuy,int &cntSell)
{
    cntBuy=0;
    cntSell=0;
    
    int total=PositionsTotal()-1;
    
    for(int i=total;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         ulong MagicNo=PositionGetInteger(POSITION_MAGIC);
         if(PositionSelectByTicket(ticket))
           {
              if(MagicNo==InpMagicNumber)
                {
                  if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){ cntBuy++;}
                  if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){ cntSell++;}
                }
           }
      }
      
      return true;
}

void ClosePosition(int buy_sell)
{
       
    int total=PositionsTotal()-1;
    
    for(int i=total;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         ulong MagicNo=PositionGetInteger(POSITION_MAGIC);
         if(PositionSelectByTicket(ticket))
           {
              if(MagicNo==InpMagicNumber)
                {
                  if(!buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){ continue;}
                  if(buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){ continue;}
                  trade.PositionClose(ticket);
                }
           }
      }
      
      //return true;
}  

//New bar
bool IsNewBar()
{
   static datetime previousTime=0;
   datetime currentTime=iTime(_Symbol,PERIOD_CURRENT,0);
   if(previousTime!=currentTime)
     {
      previousTime=currentTime;
      return true;
     }
   return false;
}

//Check Size Filter
bool CheckSizeFilter()
{
   if(InpSizeFilter>0 && (high-low)>InpSizeFilter*_Point)
     {
       Print("Rejected Size: ",(string)(high-low)," InpFil: ",InpSizeFilter*_Point);
       return false;
     }
     
     return true;
}

void UpdateStopLoss(int slDistance)
{
   int total=PositionsTotal();
   for(int i=total-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket<=0){Print("Failed to get Position Ticket"); return;}
      if(!PositionSelectByTicket(ticket)){Print("Failed to select the ticket");return;}
      long magicnumber;
      if(!PositionGetInteger(POSITION_MAGIC,magicnumber)){Print("Failed to get Position Magic Number");return;}
      if(magicnumber==InpMagicNumber)
        {
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type)){Print("Failed to get Position Type");return;}
         
         double currentSL,currentTP;
         if(!PositionGetDouble(POSITION_SL,currentSL)){Print("Failed to get current Position Stop Loss");return;}
         if(!PositionGetDouble(POSITION_TP,currentTP)){Print("Failed to get current Position Take Profit");return;}
         
         
         double currentPrice=type==POSITION_TYPE_BUY?currentTick.bid :currentTick.ask;
         int n = type==POSITION_TYPE_BUY?1:-1;
         double newSL=currentPrice-slDistance*n*_Point;
         if(!NormalizePrice(newSL)){return;}
         
         if((newSL*n)<(currentSL*n) || NormalizeDouble(MathAbs(newSL-currentSL),_Digits)<_Point)
           {
             continue;
           }
         long level=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
         if(level!=0 && MathAbs(currentPrice-newSL)<=level*_Point)
           {
            Print("New Stop Loss inside Stop  Level");
            continue;
           } 
         if(!trade.PositionModify(ticket,newSL,currentTP))
           {
             Print("Failed to Modify new Sl ",ticket);
             return;
           }   
        }
     }

}