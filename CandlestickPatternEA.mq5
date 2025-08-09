#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Defines                                                          |
//+------------------------------------------------------------------+
#define NR_CONDITIONS 6 //number of conditions
//+------------------------------------------------------------------+
//|includes                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//|Global Variables                                                  |
//+------------------------------------------------------------------+
enum MODE{
  OPEN=0, //open
  HIGH=1, //high
  LOW=2,  //low
  CLOSE=3, //close
  RANGE=4, //range abs(high-low)
  BODY=5,  //body abs(open-close)
  RATIO=6, //ratio (range/body)
  VALUE=7, //value 
};

enum INDEX{
  INDEX_0=0, //index 0
  INDEX_1=1, //index 1
  INDEX_2=2, //index 2
  INDEX_3=3, //index 3
};

enum COMPARE{
  GREATER, //greater
  LESS,    //less
};

struct CONDITION{
  bool active; //condition active?
  MODE modeA ; //mode A
  INDEX idxA; //index A
  COMPARE comp; // compare
  MODE modeB ; //mode B
  INDEX idxB; //index B
  double value; //value
  
  CONDITION() :active(false){};
   
};

CONDITION con[NR_CONDITIONS]; //condition array
MqlTick currentTick;          //current tick of the symbol
CTrade trade; 
int handleMA;                 
//+------------------------------------------------------------------+
//|Inputs                                                            |
//+------------------------------------------------------------------+
input  group "====General===="
static input long InpMagicNumber=87656; //magic number
static input double InpLotSize =0.01;   //Lot Size
input  int   InpTakeProfit     =600;    //Take profit (0=off)
input  int   InpStopLoss       =200;    //Stop Loss (0=off)
input  string InpNameofpattern ="Engulfing bar";  //Candle Pattern Name
input  group "======Moving average setting====="
input  bool  InpMaActive     =false;    //activate MA
input  int   InpMaPeriod     =100;      //MA period


input  group "===Condition 1===="
input  bool  InpCon1Active  =true;     //active
input  MODE  InpCon1ModeA   =OPEN;      //mode A
input  INDEX InpCon1IndexA  =INDEX_1;    //index A
input  COMPARE InpCon1compare =GREATER;   //compare
input  MODE  InpCon1ModeB   =CLOSE;      //mode B
input  INDEX InpCon1IndexB  =INDEX_1;    //index B
input  double InpCon1Value  =0;          //value

input  group "===Condition 2===="
input  bool  InpCon2Active  =false;     //active
input  MODE  InpCon2ModeA   =OPEN;      //mode A
input  INDEX InpCon2IndexA  =INDEX_1;    //index A
input  COMPARE InpCon2compare =GREATER;   //compare
input  MODE  InpCon2ModeB   =CLOSE;      //mode B
input  INDEX InpCon2IndexB  =INDEX_1;    //index B
input  double InpCon2Value  =0;          //value

input  group "===Condition 3===="
input  bool  InpCon3Active  =false;     //active
input  MODE  InpCon3ModeA   =OPEN;      //mode A
input  INDEX InpCon3IndexA  =INDEX_1;    //index A
input  COMPARE InpCon3compare =GREATER;   //compare
input  MODE  InpCon3ModeB   =CLOSE;      //mode B
input  INDEX InpCon3IndexB  =INDEX_1;    //index B
input  double InpCon3Value  =0;          //value

input  group "===Condition 4===="
input  bool  InpCon4Active  =false;     //active
input  MODE  InpCon4ModeA   =OPEN;      //mode A
input  INDEX InpCon4IndexA  =INDEX_1;    //index A
input  COMPARE InpCon4compare =GREATER;   //compare
input  MODE  InpCon4ModeB   =CLOSE;      //mode B
input  INDEX InpCon4IndexB  =INDEX_1;    //index B
input  double InpCon4Value  =0;          //value

input  group "===Condition 5===="
input  bool  InpCon5Active  =false;     //active
input  MODE  InpCon5ModeA   =OPEN;      //mode A
input  INDEX InpCon5IndexA  =INDEX_1;    //index A
input  COMPARE InpCon5compare =GREATER;   //compare
input  MODE  InpCon5ModeB   =CLOSE;      //mode B
input  INDEX InpCon5IndexB  =INDEX_1;    //index B
input  double InpCon5Value  =0;          //value

input  group "===Condition 6===="
input  bool  InpCon6Active  =false;     //active
input  MODE  InpCon6ModeA   =OPEN;      //mode A
input  INDEX InpCon6IndexA  =INDEX_1;    //index A
input  COMPARE InpCon6compare =GREATER;   //compare
input  MODE  InpCon6ModeB   =CLOSE;      //mode B
input  INDEX InpCon6IndexB  =INDEX_1;    //index B
input  double InpCon6Value  =0;          //value

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //set the inputs before we check the input
   SetInputs();
   //check inputs
   if(!CheckInputs()){ return INIT_PARAMETERS_INCORRECT;}
   
   
   
   //get Ma indicator
   handleMA=iMA(_Symbol,PERIOD_CURRENT,InpMaPeriod,0,MODE_SMA,PRICE_CLOSE);
   if(handleMA==INVALID_HANDLE){Print("unable to load MA indicator"); return INIT_FAILED;}
     
      
    
    
   //set magic number
   trade.SetExpertMagicNumber(InpMagicNumber);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    if(handleMA!=INVALID_HANDLE){IndicatorRelease(handleMA);}   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    //check current tick is new bar open tick
    if(!IsNewBar()){return;}
    //get the current Symbol tick
    if(!SymbolInfoTick(_Symbol,currentTick)){Print("Failed to get Current tick"); return;}
    //count open positions
    int cntBuy,cntSell;
    if(!CountOpenPositions(cntBuy,cntSell)){Print("Failed to count open positions"); return;}
    
    //check condition to open buy condition
    if(cntBuy==0 && CheckAllConditions(true) && CheckMAFilter(true))
      {
       //calculate stoploss and Take profit
       double sl=InpStopLoss==0?0:currentTick.bid-InpStopLoss*_Point;
       double tp=InpTakeProfit==0?0:currentTick.bid+InpTakeProfit*_Point;
       
       if(!NormalizePrice(sl,sl)){Print("Failed to Normalize sl"); return;}
       if(!NormalizePrice(tp,tp)){Print("Failed to Normalize tp"); return;}
       
       DrawObject(1, iHigh(_Symbol,PERIOD_CURRENT,1),true,"Bullish");
      
       
       trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLotSize,currentTick.ask,sl,tp,"Candle stick Pattern Buy");
       
      }
    //check condition to open sell position
    if(cntSell==0 && CheckAllConditions(false)&& CheckMAFilter(false))
      {
       //calculate stoploss and Take profit
       double sl=InpStopLoss==0?0:currentTick.ask+InpStopLoss*_Point;
       double tp=InpTakeProfit==0?0:currentTick.ask-InpTakeProfit*_Point;
       
       if(!NormalizePrice(sl,sl)){Print("Failed to Normalize sl"); return;}
       if(!NormalizePrice(tp,tp)){Print("Failed to Normalize tp"); return;}
       
       DrawObject(1, iHigh(_Symbol,PERIOD_CURRENT,1),false,"Bearish");
       
       trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLotSize,currentTick.bid,sl,tp,"Candle stick Pattern Sell");
      }  
   
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Custom functions                                                |
//+------------------------------------------------------------------+

void SetInputs()
{
  //condition 1
  con[0].active=InpCon1Active;
  con[0].modeA =InpCon1ModeA;
  con[0].idxA =InpCon1IndexA;
  con[0].comp =InpCon1compare;
  con[0].modeB =InpCon1ModeB;
  con[0].idxB =InpCon1IndexB;
  con[0].value =InpCon1Value;
 
  //condition 2
  con[1].active=InpCon2Active;
  con[1].modeA =InpCon2ModeA;
  con[1].idxA =InpCon2IndexA;
  con[1].comp =InpCon2compare;
  con[1].modeB =InpCon2ModeB;
  con[1].idxB =InpCon2IndexB;
  con[1].value =InpCon2Value;
  
  
  //condition 3
  con[2].active=InpCon3Active;
  con[2].modeA =InpCon3ModeA;
  con[2].idxA =InpCon3IndexA;
  con[2].comp =InpCon3compare;
  con[2].modeB =InpCon3ModeB;
  con[2].idxB =InpCon3IndexB;
  con[2].value =InpCon3Value;
  
  
  //condition 4
  con[3].active=InpCon4Active;
  con[3].modeA =InpCon4ModeA;
  con[3].idxA =InpCon4IndexA;
  con[3].comp =InpCon4compare;
  con[3].modeB =InpCon4ModeB;
  con[3].idxB =InpCon4IndexB;
  con[3].value =InpCon4Value;
  
  //condition 5
  con[4].active=InpCon5Active;
  con[4].modeA =InpCon5ModeA;
  con[4].idxA =InpCon5IndexA;
  con[4].comp =InpCon5compare;
  con[4].modeB =InpCon5ModeB;
  con[4].idxB =InpCon5IndexB;
  con[4].value =InpCon5Value;
  
  
  //condition 6
  con[5].active=InpCon6Active;
  con[5].modeA =InpCon6ModeA;
  con[5].idxA =InpCon6IndexA;
  con[5].comp =InpCon6compare;
  con[5].modeB =InpCon6ModeB;
  con[5].idxB =InpCon6IndexB;
  con[5].value =InpCon6Value;
  
  


}

//check Inputs

bool CheckInputs()
{
   if(InpMagicNumber<=0)
     {
      Alert("wrong input MagicNumber<=0");
      return false;
     }
   if(InpLotSize<=0)
     {
      Alert("wrong input LotSize<=0");
      return false;
     } 
    if(InpStopLoss<=0)
     {
      Alert("wrong input StopLoss<=0");
      return false;
     }
     if(InpTakeProfit<0)
     {
      Alert("wrong input InpTakeProfit<0");
      return false;
     }  
    //check conditions +++    

   return true;
}

//check if we have a bar open tick
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
//count open Positions
bool CountOpenPositions(int &cntBuy, int &cntSell)
{
  cntBuy=0;
  cntSell=0;
  
  int total=PositionsTotal();
  for(int i=total-1;i>=0;i--)
    {
     ulong positionTicket = PositionGetTicket(i);
     if(positionTicket<=0){Print("Failed to get Position Ticket"); return false;}
     if(!PositionSelectByTicket(positionTicket)){Print("Failed to select position"); return false;}
     long magicnumber;
     if(!PositionGetInteger(POSITION_MAGIC,magicnumber)){Print("failed to get Position magic number"); return false;}
     
     if(magicnumber==InpMagicNumber)
       {
          long type;
          if(!PositionGetInteger(POSITION_TYPE,type)){Print("failed to get Position Type number"); return false;}
          if(type==POSITION_TYPE_BUY){cntBuy++;}
          if(type==POSITION_TYPE_SELL){cntSell++;}
       }
    }
  return true;
}

bool NormalizePrice(double price, double &normalizeprice)
{
  double tickSize=0;
  if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,tickSize)){Print("Failed to get tick size"); return false;}
  normalizeprice=NormalizeDouble(MathRound(price/tickSize)*tickSize,_Digits);
  return true;
}


//Close open Positions
bool ClosePositions(int all_buy_sell)
{
  
  
  int total=PositionsTotal();
  for(int i=total-1;i>=0;i--)
    {
     ulong positionTicket = PositionGetTicket(i);
     if(positionTicket<=0){Print("Failed to get Position Ticket"); return false;}
     if(!PositionSelectByTicket(positionTicket)){Print("Failed to select position"); return false;}
     long magicnumber;
     if(!PositionGetInteger(POSITION_MAGIC,magicnumber)){Print("failed to get Position magic number"); return false;}
     
     if(magicnumber==InpMagicNumber)
       {
          long type;
          if(!PositionGetInteger(POSITION_TYPE,type)){Print("failed to get Position Type number"); return false;}
          if(all_buy_sell==1 && type==POSITION_TYPE_SELL){continue;}
          if(all_buy_sell==2 && type==POSITION_TYPE_BUY){continue;}
           trade.PositionClose(positionTicket);
          if(trade.ResultRetcode()!=TRADE_RETCODE_DONE)
            {
             Print("Failed to Close the Position ticket: "+(string)positionTicket," result: "+(string)trade.ResultRetcode(),": ",trade.ResultRetcodeDescription());
            } 
       }
    }
  return true;
}

//check condition

bool CheckAllConditions(bool buy_sell)
{
  //check each condition
  for(int i=0;i<NR_CONDITIONS;i++)
    {
      if(!CheckOneCondition(buy_sell,i)){return false;}
    }

   return true;
}

bool CheckOneCondition(bool buy_sell, int i)
{
  //return true if condition is not active
  if(!con[i].active){return true; }
  //get bar data
  MqlRates rates[];
  ArraySetAsSeries(rates,true);
  int copied=CopyRates(_Symbol,PERIOD_CURRENT,0,4,rates);
  
  if(copied!=4){Print("Failed to get bar data: copyid: ",copied); return false;}
  //set value to a and b
  double a=0;
  double b=0;
  
  switch(con[i].modeA)
    {
     case OPEN :a=rates[con[i].idxA].open; break;
     case HIGH :a=buy_sell? rates[con[i].idxA].high:rates[con[i].idxA].low; break;
     case LOW :a=buy_sell? rates[con[i].idxA].low:rates[con[i].idxA].high; break;  
     case CLOSE :a=rates[con[i].idxA].close; break; 
     case RANGE :a=(rates[con[i].idxA].high-rates[con[i].idxA].low)/_Point; break;      
                                               
     case BODY :a=MathAbs(rates[con[i].idxA].open-rates[con[i].idxA].close)/_Point; break; 
     case RATIO :a=MathAbs(rates[con[i].idxA].open-rates[con[i].idxA].close)/
                   (rates[con[i].idxA].high-rates[con[i].idxA].low); break;
     case VALUE :a=con[i].value; break; 
     default: return false;
                    
    }
    switch(con[i].modeB)
    {
     case OPEN :b=rates[con[i].idxB].open;  break;
     case HIGH :b=buy_sell? rates[con[i].idxB].high:rates[con[i].idxB].low; break;
     case LOW :b=buy_sell? rates[con[i].idxB].low:rates[con[i].idxB].high; break;  
     case CLOSE :b=rates[con[i].idxB].close; break; 
     case RANGE :b=(rates[con[i].idxB].high-rates[con[i].idxB].low)/_Point; break;
      
     case BODY :b=MathAbs(rates[con[i].idxB].open-rates[con[i].idxB].close)/_Point; break; 
     case RATIO :b=MathAbs(rates[con[i].idxB].open-rates[con[i].idxB].close)/
                   (rates[con[i].idxB].high-rates[con[i].idxB].low); break;
     case VALUE :b=con[i].value; break; 
     default: return false;
                    
    }
    //compare values
    if(buy_sell || (!buy_sell && con[i].modeA>=4))
      {
       if(con[i].comp==GREATER && a >b){  return true;}
       if(con[i].comp==LESS && a<b){  return true;}
         
      }else
         {
       if(con[i].comp==GREATER && a <b){  return true;}
       if(con[i].comp==LESS && a>b){  return true;}
         
         }
  
  
  return false;
}

//check MA
bool CheckMAFilter(bool buy_sell)
{
   //if ma is inactive
   if(!InpMaActive){return true;}
   
   double maBuffer[];
   int copied=CopyBuffer(handleMA,0,1,1,maBuffer);
   if(copied!=1){Print("unable to get MA value"); return false;}
   ArraySetAsSeries(maBuffer,true);
   if(buy_sell && currentTick.ask>maBuffer[0]){Print("we are in Uptrend"); return true;}
   if(!buy_sell && currentTick.bid<maBuffer[0]){Print("we are in DownTrend"); return true;}
    

  return false;
}


void DrawObject(int candleIndex, double highPrice ,bool buy_sell, string type)
{
  // Create a unique object name (avoid conflicts)
   string objName = "HighText_" + TimeToString(iTime(_Symbol, _Period, candleIndex));

   // Create the text object
   if(!ObjectCreate(0, objName, OBJ_TEXT, 0, iTime(_Symbol, _Period, candleIndex), highPrice))
   {
      Print("Failed to create text object: ", GetLastError());
      return;
   }

   // Set text properties
   ObjectSetString(0, objName, OBJPROP_TEXT,type+" "+InpNameofpattern);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, buy_sell?clrBlue:clrRed);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);

   // Shift it slightly above the high
   double shift = (highPrice * 0.001); // adjust for your symbol
   ObjectMove(0, objName, 0, iTime(_Symbol, _Period, candleIndex), highPrice + shift);

}