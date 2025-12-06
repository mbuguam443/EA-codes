
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade trade;

input ulong InpMagicNumber=98763;
input int ATRPeriod=8;
input int NumberofBarCounted=1;

input int PercentRisk=2;

input int TpPoints=600;
input int SlPoints=200;
input double LowestRiskAmount=3.0;


int totalBars;


int handleBoomCrash;
int OnInit()
  {
   
   handleBoomCrash=iCustom(_Symbol,PERIOD_CURRENT,"Market/Boom and crash smasher.ex5",ATRPeriod,NumberofBarCounted,false,0,false,false);
     
   totalBars=iBars(_Symbol,PERIOD_CURRENT);
   trade.SetExpertMagicNumber(InpMagicNumber);
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason)
  {

   
  }
void OnTick()
  {
    
    int bars=iBars(_Symbol,PERIOD_CURRENT);
    if(totalBars!=bars)
      {
       totalBars=bars;
       
       int cntBuy=0,cntSell=0;
       Countpositions(cntBuy,cntSell);
       
        double boomBuy[],boomSell[];
        
        CopyBuffer(handleBoomCrash,0,1,1,boomSell);
        CopyBuffer(handleBoomCrash,1,1,1,boomBuy);
        
        if(boomSell[0]>0 && cntSell==0)
          {
            Print("Sell Now ");
            double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
            
            double tp=entry-TpPoints*_Point;
            double sl=SlPoints==0?boomSell[0]: entry+SlPoints*_Point;
            
            tp=NormalizeDouble(tp,_Digits);
            sl=NormalizeDouble(sl,_Digits);
            double lots=CalculateLotSize(PercentRisk,sl-entry);
            trade.Sell(lots,_Symbol,entry,sl,tp,"Boom and Crash Buy");
          }
        if(boomBuy[0]>0 && cntBuy==0)
          {
            Print("Buy Now");
            double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
            
            double tp=entry+TpPoints*_Point;
            double sl=SlPoints==0?boomSell[0]: entry-SlPoints*_Point;
            
            tp=NormalizeDouble(tp,_Digits);
            sl=NormalizeDouble(sl,_Digits);
            double lots=CalculateLotSize(PercentRisk,entry-sl);
            trade.Buy(lots,_Symbol,entry,sl,tp,"Boom and Crash Sell");
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
              if(MagicNo==InpMagicNumber)
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
              if(MagicNo==InpMagicNumber)
                {
                  if(!buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){ continue;}
                  if(buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){ continue;}
                  trade.PositionClose(ticket);
                }
           }
      }
}

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
   Print("riskMoney: ",riskMoney," smallest you can riskMoney: ",moneyPerSmallestLotsize);
   if(moneyPerSmallestLotsize==0)
     {
      return 0;
     }
   double lotsFactor= (riskMoney/moneyPerSmallestLotsize);  
   double lots= MathFloor(riskMoney/moneyPerSmallestLotsize)* ticklotStep;
   if(moneyPerSmallestLotsize >riskMoney)
     {
      if(moneyPerSmallestLotsize > LowestRiskAmount)
        {
          return 0;
        }else
           {
             lots=ticklotMin;
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