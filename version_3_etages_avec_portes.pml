mtype = {eteint, allume} ; /* etat des boutons */
mtype = {fermees, ouvertes, refermees} ; /* etat des portes */
chan EC = [4] of {short, byte} ; /* Canal d'envoi des appels aux étages vers la cabine représentés 
par un couple {Direction(-1,+1), N° d'étages(0,1 ou 2)} */
chan CE = [0] of {short, byte} ; /* Canal d'envoi des commandes d'extinction des boutons de la cabine vers les étages représentées par un couple {Direction(-1,+1), N° d'étages(0,1 ou 2)} */
chan CP = [0] of {short, byte} ; /* Canal d'envoi de l'état des portes dans la cabine vers l'étage par un couple {Etat porte(0,1,2), Position(0,1 ou 2)} */
chan EP = [0] of {short, byte} ; /* Canal d'envoi de l'état des portes de l'étage vers la cabinepar un couple {Etat porte(0,1,2), N° d'étages(0,1 ou 2)} */
proctype Cabine() 
{ 
	/* Invariant P0 La cabine est soit à l’étage 0,1 ou 2 et sa direction est soit vers le bas -1, soit vers le haut +1 */
	assert((Cabine:Pos == 0 || Cabine:Pos == 1 || Cabine:Pos == 2) && (Cabine:Dir == 1 || Cabine:Dir == -1)) 
	
	
	
	/* Déclaration des varaibles et Initialisation */
	byte Pos = 0 ; /* Position de la cabine */
	short Dir = 1 ; /* Direction de déplacement de la cabine : monte (1), descend(-1) */ 
	short DirPrec = 1;
	
	
	mtype PC = fermees;	
	short CA = 0; /* 0 cabine arret, 1 cabine mouvement*/
	
	mtype B0 = eteint, B1 = eteint, B2 = eteint ; 
		/* Etat des boutons interne à la cabine pour les étages 0,1 et 2 */
	mtype BM0 = eteint, BM1 = eteint, BD1 = eteint, BD2 = eteint ; 
		/* Etat des boutons externe pour monter (M) ou descendre (D) connu de la cabine pour les étages 0,1 et 2 */
	
	do
		
		
		/* Changements de direction */ 
		::atomic{ (Pos==0 && Dir==-1) -> DirPrec=Dir ; Dir=1 ;} progress0 : skip;
		::atomic{ (Pos==2 && Dir==1) -> DirPrec=Dir ; Dir=-1 ;} progress1 : skip;
		::atomic{ (Pos==1 && Dir==-1 && (B2==allume || BD2==allume || BM1==allume) && (B0==eteint && BM0==eteint && BD1==eteint)) -> DirPrec=Dir ; Dir=1} progress2 : skip;
		::atomic{ (Pos==1 && Dir==1 && (B0==allume || BM0==allume || BD1==allume) && (B2==eteint && BD2==eteint && BM1==eteint)) -> DirPrec=Dir ; Dir=-1} progress3 : skip;
			
		/* Déplacement de la cabine */
		
		/* Montée de l'étage 0 vers l'étage 1 */
		::atomic{(Dir==1 && Pos==0 && (B1==allume || B2==allume || BM0==allume ||
			BM1==allume || BD1==allume || BD2==allume) && PC == refermees && CA == 1) -> Pos=1 ; B1 = eteint;PC = fermees; 
				if	:: BM0==allume -> DirPrec=Dir;BM0=eteint ; CE! Dir, 0 ;
					:: else DirPrec=Dir;
				fi } 
		/* Montée de l'étage 1 vers l'étage 2*/
		::atomic{(Dir==1 && Pos==1 && (B2==allume || BM1==allume || BD2==allume) && PC == refermees && CA == 1) -> Pos=2 ; B2 = eteint ;PC = fermees ;
				if	:: BM1==allume -> DirPrec=Dir;BM1=eteint ; CE! Dir, 1 ;
					:: else DirPrec=Dir;
				fi } 
		/* Descente de l'étage 2 vers l'étage 1*/
		::atomic{(Dir==-1 && Pos==2 && (B0==allume || B1==allume || BM0==allume ||
			BM1==allume || BD1==allume || BD2==allume)&& PC == refermees && CA == 1) -> Pos=1 ; B2 = eteint ;PC = fermees ;
				if	:: BD2==allume -> DirPrec=Dir;BD2=eteint ; CE! Dir, 2 ;
					:: else DirPrec=Dir;
				fi } 
		/* Descente de l'étage 1 vers l'étage 0*/
		::atomic{(Dir==-1 && Pos==1 && (B0==allume || BM0==allume || BD1==allume)&& PC == refermees && CA == 1) -> Pos=0 ; B0 = eteint ;PC = fermees ;
				if	:: BD2==allume -> DirPrec=Dir;BD2=eteint ; CE! Dir, 1 ;
					:: else DirPrec=Dir;
				fi } 
		/*Appel interne à la cabine */
		/*Appel depuis cabine de l'étage 0  */
		::atomic {(Pos==1 || Pos==2) -> B0=allume;DirPrec=Dir;} progress4 : skip;
		/*Appel depuis cabine de l'étage 1  */
		::atomic {(Pos==0 || Pos==2) -> B1=allume;DirPrec=Dir;} progress5 : skip;
		/*Appel depuis cabine de l'étage 0  */
		::atomic {(Pos==0 || Pos==1) -> B2=allume;DirPrec=Dir;} progress6 : skip;
		
		/*Réception de l'état des boutons des étages */
		/*Demande pour monter de l'étage 0 */
		::atomic{EC? 1,0 ->BM0=allume;DirPrec=Dir;}
		/*Demande pour monter de l'étage 1 */
		::atomic{EC? 1,1 ->BM1=allume;DirPrec=Dir;} 
		/*Demande pour descendre de l'étage 1 */
		::atomic{EC? -1,1 ->BD1=allume;DirPrec=Dir;} 
		/*Demande pour descendre de l'étage 2 */
		::atomic{EC? -1,2 ->BD2=allume;DirPrec=Dir;}
		
		/* Demande OuverturePorteCabine */
		/*Cabine demande à porte de l'étage de s'ouvrir*/
		::atomic{(PC == fermees) ->CA = 0;CP!1,Pos}
		
		/* OuverturePorteCabine */
		/*Cabine recoit confirmation ouverture, s'ouvre, porte étage déjà ouverte*/
		::atomic{EP?1,Pos -> PC = ouvertes;CA = 0}
		
		/* FermeturePorteCabine */
		/*Cabine se ferme, demande fermeture à étage*/
		::atomic{(PC == ouvertes) -> PC = refermees ;CP!0,Pos}
		
		/*Remise en mouvement*/
		/*La cabine recoit confirmation que l'étage est fermée */
		::atomic{EP?0,Pos -> CA = 1}
		
		
		
		
	/*Fin processus cabine */
	od
}
		
proctype Etages(){
	/*Déclaration des variables et initialisations */
	mtype M0 = eteint, M1 = eteint, D1 = eteint, D2 = eteint;
	mtype PE0 = fermees;	
	mtype PE1 = fermees;	
	mtype PE2 = fermees;	
	
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
		
		/* ETAGE 0 */
		/* OuverturePorteEtage */
		/*Etage reçoit demande d'ouverture, s'ouvre, et donne ordre ouverture à cabine*/
		::atomic{ 
			CP?1,0 -> PE0 = ouvertes;EP!1,0;
		}
		/*FermeturePorteEtage */
		::atomic{
		/*Etage reçoit demande de fermeture, se ferme, cabine déjà fermé*/
			CP?0,0 -> PE0 = fermees;EP!0,0;
		}
			
		/* ETAGE 1 */
		/* OuverturePorteEtage */
		/*Etage reçoit demande d'ouverture, s'ouvre, et donne ordre ouverture à cabine*/
		::atomic{ 
			CP?1,1 -> PE1 = ouvertes;EP!1,1;
		}
		/*FermeturePorteEtage */
		::atomic{
		/*Etage reçoit demande de fermeture, se ferme, cabine déjà fermée*/
			CP?0,1 -> PE1 = fermees ;EP!0,1;
		}
			
		/* ETAGE 2 */
		/* OuverturePorteEtage */
		/*Etage reçoit demande d'ouverture, s'ouvre, et donne ordre ouverture à cabine*/
		::atomic{ 
			CP?1,2 -> PE2 = ouvertes;EP!1,2;
		}
		/*FermeturePorteEtage */
		::atomic{
		/*Etage reçoit demande de fermeture, se ferme, cabine déjà fermée*/
			CP?0,2 -> PE2 = fermees ;EP!0,2;
		}			
			
			
		/* fin processus Etages */
	od 
}

init{
	atomic {
		run Cabine();
		run Etages(); 
	}
}

/*ltl p1{[] (Cabine:Dir != Cabine:DirPrec-> 
	(Cabine:Pos == 0 && Cabine:DirPrec == -1) ||
	(Cabine:Pos == 2 && Cabine:DirPrec == 1) ||
	((Cabine:Pos == 1 && Cabine:DirPrec == -1) &&
		(Cabine:B2==allume || Cabine:BD2==allume || Cabine:BM1==allume) && (Cabine:B0==eteint && Cabine:BM0==eteint && Cabine:BD1==eteint)) ||
	((Cabine:Pos == 1 && Cabine:DirPrec == 1) &&
		(Cabine:B0==allume || Cabine:BM0==allume || Cabine:BD1==allume) && (Cabine:B2==eteint && Cabine:BD2==eteint && Cabine:BM1==eteint))
	)
	} ;


/* Les portes aux étages sont toujours fermées sauf si la cabine est positionnée à l’étage où les portes de l’étage sont ouvertes. */
/*ltl p2{[] (
	(Etages:PE0 == fermees -> Cabine:Pos != 0) || 
	(Cabine:Pos == 0 && Cabine:PC == ouvertes -> Etages:PE0 == ouvertes )||
	(Etages:PE1 == fermees -> Cabine:Pos != 1) ||
	(Cabine:Pos == 1 && Cabine:PC == ouvertes -> Etages:PE1 == ouvertes )||
	(Etages:PE2 == fermees -> Cabine:Pos != 2) ||
	(Cabine:Pos == 2 && Cabine:PC == ouvertes -> Etages:PE2 == ouvertes )
	)
} */
/* Pendant un déplacement de l’étage i vers l’étage suivant toutes les portes sont fermées ou refermées. */
/*ltl p3{[] (
		Cabine:CA == 1 -> 
			Etages:PE0 == fermees &&
			Etages:PE1 == fermees && 
			Etages:PE2 == fermees &&
			(Cabine:PC == refermees || Cabine:PC == fermees)
	)
} 
*/
/* Si la cabine se déplace de l’étage i vers l’étage j, c’est qu’il y avait des demandes d’usagers à l’étage j. */
/*ltl p4{[] (
		(Cabine:CA == 1 && Cabine:Pos == 1 && Cabine:Dir == 1 -> (Cabine:B2==allume || Cabine:BD2==allume || Cabine:BM1==allume)) ||
		(Cabine:CA == 1 && Cabine:Pos == 1 && Cabine:Dir == -1 -> (Cabine:B0==allume || Cabine:BM0==allume || Cabine:BD1==allume)) ||
		(Cabine:CA == 1 && Cabine:Pos == 0  -> (Cabine:BM0==allume || Cabine:BD1==allume || Cabine:B0==allume)) ||
		(Cabine:CA == 1 && Cabine:Pos == 2  -> (Cabine:BD2==allume || Cabine:BM1==allume || Cabine:B2==allume)) 	
	)
} */
/* Toute demande d’un usager à l’étage NE-1 ou dans la cabine pour l’étage NE-1 est inévitablement servie par la cabine. */
/*ltl p5{[] (
		((Cabine:B0==allume || Cabine:BD1==allume) -> <>(Cabine:Pos == 0)) ||
		((Cabine:BM0==allume || Cabine:BD2==allume || Cabine:B1==allume) -> <>(Cabine:Pos == 1)) ||
		((Cabine:B2==allume || Cabine:BM1==allume) -> <>(Cabine:Pos == 2)) 
	)
} */
/* Il y a des demandes usager infiniment souvent à chaque étage et dans toutes les directions possibles. */
/*ltl p6{[](
	[]<> (Cabine:B0==allume) && 
	[]<> (Cabine:B1==allume) &&
	[]<> (Cabine:B2==allume) &&
	[]<> (Cabine:BM0==allume) &&
	[]<> (Cabine:BM1==allume) &&
	[]<> (Cabine:BD1==allume) &&
	[]<> (Cabine:BD2==allume) 
	)
}*/



