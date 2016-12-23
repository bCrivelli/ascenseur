mtype = {eteint, allume} ; /* etat des boutons */
mtype = {fermees, ouvertes, refermees} ; /* etat des portes */
chan EC = [4] of {short, byte} ; /* Canal d'envoi des appels aux étages vers la cabine représentés 
par un couple {Direction(-1,+1), N° d'étages(0,1 ou 2)} */

chan CE = [0] of {short, byte} ; /* Canal d'envoi des commandes d'extinction des boutons de la cabine vers les étages représentées par un couple {Direction(-1,+1), N° d'étages(0,1 ou 2)} */

proctype Cabine() 
{ 

	/* Déclaration des varaibles et Initialisation */
	byte Pos = 0 ; /* Position de la cabine */
	short Dir = 1 ; /* Direction de déplacement de la cabine : monte (1), descend(-1) */ 
	
	mtype PorteCab = fermees;	
	
	mtype B0 = eteint, B1 = eteint, B2 = eteint ; 
		/* Etat des boutons interne à la cabine pour les étages 0,1 et 2 */
	mtype BM0 = eteint, BM1 = eteint, BD1 = eteint, BD2 = eteint ; 
		/* Etat des boutons externe pour monter (M) ou descendre (D) connu de la cabine pour les étages 0,1 et 2 */
	
	do
		/* Invariant P0 La cabine est soit à l’étage 0,1 ou 2 et sa direction est soit vers le bas -1, soit vers le haut +1 */
		::assert((Pos == 0 || Pos == 1 || Pos == 2) && (Dir == 1 || Dir == -1))	
		
		/* Changements de direction */
		::atomic{ (Pos==0 && Dir==-1) -> Dir=1 ;}
		::atomic{ (Pos==2 && Dir==1) -> Dir=-1 ;} 
		::atomic{ (Pos==1 && Dir==1 && 
			(B0==allume || BM0==allume || BD1==allume)) -> Dir=-1 ;} 
		::atomic{ (Pos==1 && Dir==-1 && 
			(B2==allume || BD2==allume || BM1==allume)) -> Dir=1 ;}
			
		/* Déplacement de la cabine */
		
		/* Montée de l'étage 0 vers l'étage 1 */
		::atomic{(Dir==1 && Pos==0 && (B1==allume || B2==allume || BM0==allume ||
			BM1==allume || BD1==allume || BD2==allume)) -> Pos=1 ; B1 = eteint ;
				if	:: BM0==allume -> BM0=eteint ; CE! Dir, 0 ;
					:: else skip
				fi }
		/* Montée de l'étage 1 vers l'étage 2*/
		::atomic{(Dir==1 && Pos==1 && (B2==allume || BM1==allume || BD2==allume)) -> Pos=2 ; B2 = eteint ;
				if	:: BM1==allume -> BM1=eteint ; CE! Dir, 1 ;
					:: else skip
				fi }
		/* Descente de l'étage 2 vers l'étage 1*/
		::atomic{(Dir==-1 && Pos==2 && (B0==allume || B1==allume || BM0==allume ||
			BM1==allume || BD1==allume || BD2==allume)) -> Pos=1 ; B2 = eteint ;
				if	:: BD2==allume -> BD2=eteint ; CE! Dir, 2 ;
					:: else skip
				fi }
		/* Descente de l'étage 1 vers l'étage 0*/
		::atomic{(Dir==-1 && Pos==1 && (B0==allume || BM0==allume || BD1==allume)) -> Pos=0 ; B0 = eteint ;
				if	:: BD2==allume -> BD2=eteint ; CE! Dir, 1 ;
					:: else skip
				fi }
		/*Appel interne à la cabine */
		:: atomic {
			/*Appel depuis cabine de l'étage 0  */
			(Pos==1 || Pos==2) -> B0=allume;
			
		}
		:: atomic {
			/*Appel depuis cabine de l'étage 1  */
			(Pos==0 || Pos==2) -> B1=allume;
			
		}:: atomic {
			/*Appel depuis cabine de l'étage 0  */
			(Pos==0 || Pos==1) -> B2=allume;
			
		}/*Réception de l'état des boutons des étages */
		::atomic{
			/*Demande pour monter de l'étage 0 */
			EC? 1,0 ->BM0=allume;
		}
		::atomic{
			/*Demande pour monter de l'étage 1 */
			EC? 1,1 ->BM1=allume;
		}
		::atomic{
			/*Demande pour descendre de l'étage 1 */
			EC? -1,1 ->BD1=allume;
		}
		::atomic{
			/*Demande pour descendre de l'étage 2 */
			EC? -1,2 ->BD2=allume;
		}
		/* OuverturePorteCabine */
		::atomic{(PorteCab == fermees) -> PorteCab = ouvertes ;}
		/* FermeturePorteCabine */
		::atomic{(PorteCab == refermees) -> PorteCab = fermees ;}
		
	/*Fin processus cabine */
	od
}
		
proctype Etages(){
	/*Déclaration des variables et initialisations */
	mtype M0 = eteint, M1 = eteint, D1 = eteint, D2 = eteint;
	mtype PorteEta = fermees;	
	
	do 
		/*Appuis aléatoire sur les boutons et allumage aléatoire */
		::atomic{
			/*Appui sur M0*/
			M0==eteint -> M0=allume; EC ! 1, 0 ; } 
		::atomic{
			/*Appui sur M1*/
			M1==eteint -> M1=allume; EC ! 1, 1 ; } 
		::atomic{
			/*Appui sur D1*/
			D1==eteint -> D1=allume; EC ! -1, 1 ; } 
		::atomic{
			/*Appui sur D2*/
			D2==eteint -> D2=allume; EC ! -1, 2 ; } 
		
		/*Prise en compte des commandes d'extinction des boutons */
		::atomic {
			/* extinction M0 */
			CE? 1,0 -> M0=eteint;
		}
		::atomic {
			/* extinction M1 */
			CE? 1,1 -> M1=eteint;
		}
		::atomic {
			/* extinction D1 */
			CE? -1,1 -> D1=eteint;
		}
		::atomic {
			/* extinction D2 */
			CE? -1,2 -> D2=eteint;
		}
		
		/* OuverturePorteEtage */
		::atomic{(PorteEta == fermees) -> PorteEta = ouvertes ;}
		/*FermeturePorteEtage */
		::atomic{(PorteEta == ouvertes) -> PorteEta = fermees ;}
	/* fin processus Etages */
	od
}

init{
	atomic {
		run Cabine();
		run Etages();
	}
}

ltl p1{[]( (Cabine:Pos == 0 && Cabine:Dir == -1) -> (Cabine:Pos == 0 U Cabine:Dir == 1))}; 
/* Les portes aux étages sont toujours fermées sauf si la cabine est positionnée à l’étage où les portes de l’étage sont ouvertes. */
/*ltl p2{[] (Etages:PorteEta == ouvertes) -> (Cabine:Pos == } */ 
/* Pendant un déplacement de l’étage i vers l’étage suivant toutes les portes sont fermées ou refermées. */
ltl p3{true}
/* Si la cabine se déplace de l’étage i vers l’étage j, c’est qu’il y avait des demandes d’usagers à l’étage j. */
ltl p4{true}
/* Toute demande d’un usager à l’étage NE-1 ou dans la cabine pour l’étage NE-1 est inévitablement servie par la cabine. */
ltl p5{true}
/* Il y a des demandes usager infiniment souvent à chaque étage et dans toutes les directions possibles. */
ltl p6{true}


