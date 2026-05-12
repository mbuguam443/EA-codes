#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/Trade.mqh>

input group "Indicator setting"
input int jawPeriod=13;
input int teethPeriod=8;
input int lipsPeriod=5;

input int MovingAvergePeriod=150;

input group "trade setting"
input int TpPoints=1000;
input int SlPoints=300;
input double lotsSize=0.01;

int barsTotal;

int handleAlligator,handleMa;

CTrade trade;

int OnInit(){
   
   handleAlligator=iAlligator(_Symbol,PERIOD_CURRENT,jawPeriod,8,teethPeriod,5,lipsPeriod,3,MODE_SMMA,PRICE_MEDIAN);
   handleMa=iMA(_Symbol,PERIOD_CURRENT,MovingAvergePeriod,0,MODE_SMA,PRICE_CLOSE);
   barsTotal=iBars(_Symbol,PERIOD_CURRENT);
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason){

   
  }
void OnTick(){

     double jaws[];
     ArraySetAsSeries(jaws,true);
     CopyBuffer(handleAlligator,GATORJAW_LINE,1,2,jaws);
     
     double teeth[];
     ArraySetAsSeries(teeth,true);
     CopyBuffer(handleAlligator,GATORTEETH_LINE,1,2,teeth);
     
     double lips[];
     ArraySetAsSeries(lips,true);
     CopyBuffer(handleAlligator,GATORLIPS_LINE,1,2,lips);
     
     double maFilter[];
     ArraySetAsSeries(maFilter,true);
     CopyBuffer(handleMa,0,1,1,maFilter);
     
     Comment("\n jaw[0]: ",jaws[0],
             "\n teeth[0]: ",teeth[0],
             "\n lips[0]: ",lips[0],
             "\n Ma[0]:",maFilter[0]);
     
     int bars=iBars(_Symbol,PERIOD_CURRENT);
     if(barsTotal<bars)
       {
        barsTotal=bars;
           if(lips[1]<teeth[1] && lips[0]>teeth[0])
             {
               double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
               if(ask > jaws[0] && ask >maFilter[0])
                 {
                    Print("Buy Now");
                    ask=NormalizeDouble(ask,_Digits);
                 double tp=ask+TpPoints*_Point;
                 tp=NormalizeDouble(tp,_Digits);
                 double sl=ask-SlPoints*_Point;
                 sl=NormalizeDouble(sl,_Digits);
                 
                 trade.Buy(lotsSize,_Symbol,ask,sl,tp,"Alligator Buy");
                 }
               
             }
           if(lips[1]>teeth[1] && lips[0]<teeth[0])
             {
              double bid =SymbolInfoDouble(_Symbol,SYMBOL_BID);
              if(bid<jaws[0] &&  bid < maFilter[0])
                {
                    Print("Sell Now");
                    bid=NormalizeDouble(bid,_Digits);
                 double tp=bid-TpPoints*_Point;
                 tp=NormalizeDouble(tp,_Digits);
                 
                 double sl=bid+SlPoints*_Point;
                 sl=NormalizeDouble(sl,_Digits); 
                 
                 trade.Sell(lotsSize,_Symbol,bid,sl,tp,"Alligator Sell");     
                }
             }  
        
       }        
     
   
  }

