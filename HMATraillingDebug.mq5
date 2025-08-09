#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include<Trade/Trade.mqh>
CTrade trade;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

input group "Fast Setting"
input int HMAPeriod=100;
input ENUM_MA_METHOD HMAMethod=MODE_LWMA;
input ENUM_APPLIED_PRICE HMAPrice=PRICE_CLOSE;

input int RiskdistanceDivider=2;
static input ulong InpMagicnumber=9876556;// Magic Number
input  double PercentRisk=2;//% risk
input double LowestRiskAmount=0.99;
input bool HmaTrailing=true;
input bool InpTrailingStop=true;
input  int    InputSellGradient=1;// HMA gradient
input  int  SlPoints=200;
input  int TpPoints=600;
input  int TrailingPoints=200;


int TrailingDistance=TrailingPoints;
int handleHMA;
int totalbars;

int OnInit()
  {
    totalbars=iBars(_Symbol,PERIOD_CURRENT);
    
    handleHMA=iCustom(_Symbol,PERIOD_CURRENT,"Market/HMA Color with Alerts MT5.ex5","",HMAPeriod,HMAMethod,HMAPrice,"",false,false,false,false,"","",false);
    trade.SetExpertMagicNumber(InpMagicnumber);
    if(handleHMA==INVALID_HANDLE)
      {
       return INIT_FAILED;
      }
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
    int bars=iBars(_Symbol,PERIOD_CURRENT);
    if(totalbars!=bars)
      {
        totalbars=bars;
        
        int gradient= detectSidewayMarket();
        double hmabuffer[];
        CopyBuffer(handleHMA,0,1,3,hmabuffer);
        int cntBuy=0,cntSell=0;
        Countpositions(cntBuy,cntSell);
        
        if(HmaTrailing)
          {
             if(cntBuy>0 )
             {
               trailing(true);
             }
            if(cntSell>0)
             {
              trailing(false);
             }
          }
        
        
        if(hmabuffer[0]>hmabuffer[1] && hmabuffer[1] < hmabuffer[2])
          {
            Print("Buy Now");
            ClosePosition(false);
            double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
            TrailingDistance=TrailingPoints==0?(int)(MathAbs(entry-hmabuffer[2])/_Point):TrailingPoints;
            
            double sl=SlPoints==0?entry-((entry-hmabuffer[2])/RiskdistanceDivider) :entry-SlPoints*_Point;
            double tp=entry+TpPoints*_Point;
            tp=NormalizeDouble(tp,_Digits);
            sl=NormalizeDouble(sl,_Digits);
            entry=NormalizeDouble(entry,_Digits);
            tp=NormalizeDouble(tp,_Digits);
            double lots=CalculateLotSize(PercentRisk,entry-sl);
            trade.Buy(lots,_Symbol,entry,sl,tp,"HMA Buy");
          }
        if(hmabuffer[0]<hmabuffer[1] && hmabuffer[1] > hmabuffer[2] )
          {
            Print("Sell Now");
            ClosePosition(true);
            double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
            TrailingDistance=TrailingPoints==0?(int)(MathAbs(entry-hmabuffer[2])/_Point):TrailingPoints;
            double sl=SlPoints==0?entry-((entry-hmabuffer[2])/RiskdistanceDivider) :entry+SlPoints*_Point;
            double tp=entry-TpPoints*_Point;
            sl=NormalizeDouble(sl,_Digits);
            entry=NormalizeDouble(entry,_Digits);
            tp=NormalizeDouble(tp,_Digits);
            double lots=CalculateLotSize(PercentRisk,sl-entry);
            trade.Sell(lots,_Symbol,entry,sl,tp,"HMA Sell");
          }
          if(InpTrailingStop)
           {
             UpdateStopLoss(TrailingDistance);
             
           }  
      }
  }
  
  void trailing(int buy_sell)
{
    double trailingbuffer[];
    CopyBuffer(handleHMA,0,1,3,trailingbuffer);
       
    int total=PositionsTotal()-1;
    
    for(int i=total;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         ulong MagicNo=PositionGetInteger(POSITION_MAGIC);
         double currentSl=PositionGetDouble(POSITION_SL);
         
         if(PositionSelectByTicket(ticket))
           {
              if(MagicNo==InpMagicnumber)
                {
                  if(buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){
                       if(currentSl<trailingbuffer[1])
                         {
                          trade.PositionModify(ticket,trailingbuffer[1],0);
                         }
                   }
                  if(!buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){ 
                      if(currentSl>trailingbuffer[1])
                         {
                          trade.PositionModify(ticket,trailingbuffer[1],0);
                         }
                  }
                }
           }
      }
}

void trailingNew(int buy_sell)
{
    double trailingbuffer[];
    CopyBuffer(handleHMA,0,1,3,trailingbuffer);
       
    int total=PositionsTotal()-1;
    
    for(int i=total;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         ulong MagicNo=PositionGetInteger(POSITION_MAGIC);
         double currentSl=PositionGetDouble(POSITION_SL);
         double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         
         if(PositionSelectByTicket(ticket))
           {
              if(MagicNo==InpMagicnumber)
                {
                  if(buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){
                       
                       
                       if(currentSl > 20*_Point)
                         {
                          //trade.PositionModify(ticket,newSl,0);
                         }
                   }
                  if(!buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){ 
                     
                     
                      if(currentSl )
                         {
                          //trade.PositionModify(ticket,newSl,0);
                         }
                  }
                }
           }
      }
}

void Countpositions(int &cntBuy,int &cntSell)
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
              if(MagicNo==InpMagicnumber)
                {
                  if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){ cntBuy++;}
                  if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){ cntSell++;}
                }
           }
      }
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
              if(MagicNo==InpMagicnumber)
                {
                  if(!buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){ continue;}
                  if(buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){ continue;}
                  trade.PositionClose(ticket);
                }
           }
      }
}

double CalculateLotSize(double Percent,double slDistance)
{
   Print("SlDistance: ",slDistance);
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
   Print("riskMoney: ",riskMoney," smallest you can riskMoney: ",moneyPerSmallestLotsize);
   Comment("Small to risk: ",DoubleToString(moneyPerSmallestLotsize));
   if(moneyPerSmallestLotsize==0)
     {
      return 0;
     }
   double lotsFactor= (riskMoney/moneyPerSmallestLotsize);  
   double lots= MathFloor(riskMoney/moneyPerSmallestLotsize)* ticklotStep;
   if(moneyPerSmallestLotsize >riskMoney)
     {
         if(LowestRiskAmount >moneyPerSmallestLotsize)
           {
            lots=ticklotMin;
           }else
              {
               lots=0;
               Print("That Risk want to kill us ");
              }
       
      
     }
   if(lots > ticklotMax)
     {
      lots=ticklotMax;
     }  
   Print("The Lot Factor between the two is: ",lotsFactor);
   Print("The Lots size to be used: ",lots);
   return lots; 
    
}


int detectSidewayMarket()
{
    double detectbuffer[];
    CopyBuffer(handleHMA,0,1,3,detectbuffer);
    int diff=(detectbuffer[2]-detectbuffer[1])/_Point;
    
    //Comment("Gradient: ",diff);
    return diff;
}

void UpdateStopLoss(int slDistance)
{
   int total=PositionsTotal();
   for(int i=total-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket<=0){Print("Failed to get Position Ticket"); return;}
      if(!PositionSelectByTicket(ticket)){Print("Failed to select the ticket");return;}
      ulong magicnumber=PositionGetInteger(POSITION_MAGIC);
      if(InpMagicnumber!=magicnumber){Print("Failed to get Position Magic Number");return;}
      if(magicnumber==InpMagicnumber)
        {
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type)){Print("Failed to get Position Type");return;}
         
         double currentSL,currentTP;
         if(!PositionGetDouble(POSITION_SL,currentSL)){Print("Failed to get current Position Stop Loss");return;}
         if(!PositionGetDouble(POSITION_TP,currentTP)){Print("Failed to get current Position Take Profit");return;}
         
         
         double currentPrice=type==POSITION_TYPE_BUY?SymbolInfoDouble(_Symbol,SYMBOL_BID) :SymbolInfoDouble(_Symbol,SYMBOL_ASK);
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