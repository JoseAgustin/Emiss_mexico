!
!	pm25_speci_p.f90
!	
!
!  Creado por Jose Agustin Garcia Reynoso el 11/06/12.
!
! Proposito:
!          Especiacion de PM2.5 en diferentes categorias para
!          fuentes puntuales
! Speciation of pm2.5 in different categories for point sources
!
!Profile #	Profile Name	SPEC	POA	PEC	GSO4	PNO3	OTHER
! POA Primary organic aerosol
! PEC elemental carbon
! PNO3 primary nitrate
! GSO4	primary sulfate
! OTHER PMFINE, generally crustal
!
!  compile: ifort -O2 -axAVX  pm25_speci_p.f90 -o spm25p.exe
!
!  Modification
!
!  Inclusion of 2 layers
!
module var_spmp
integer :: nh     !number of hours in a day
integer :: nclass !number the clasess in pm25_profiles.csv
integer lfa  ! line number in area file T_ANNPM25.txt
integer,allocatable ::grid(:)   ! grid id from emissions file
integer,allocatable ::grid2(:)   ! different grid id from emissions file
integer,allocatable :: isp(:)   ! number of chemical species in profile j
integer,allocatable ::profile(:),prof2(:) ! profile ID from file scc-profiles
integer,allocatable :: capa(:,:)   ! level of the emission
integer*8, allocatable:: iscc(:) !SCC from emissions file
real,allocatable :: ea(:,:)      ! emissions en TPM25 file grid , nh
real,allocatable :: emis(:,:,:)  ! emissions id cel, category, hours
real,allocatable :: fclass(:,:)! aggregation factor by size(prof2), nclass
character(len=4),allocatable::cname(:)
character(len=3) ::cdia
character (len=19) :: current_date

parameter (nspecies=5,nh=24)

common /date/ current_date,cdia

end module var_spmp
program pm25_speci_p
use var_spmp

	call lee
	
	call calculos
	
	call guarda

contains

subroutine lee
	implicit none
	integer :: i,j,id,idun,l
	integer*8 :: isccf
	real,dimension(5):: fagg ! aggregation factor for 5 pm2.5 species
	character(len=10) ::cdum
	character(len=25):: fname
	logical ::lfil
	fname='T_ANNPM25.csv'
	print *, 'Reading : ',trim(fname)
	open (unit=10,file=fname,status='old',action='read')
	read(10,*) cdum  ! header
	read(10,*) lfa,current_date,cdia  ! header
	i=0
	do 
        read(10,*,end=100) cdum
        i=i+1
	end do
100 continue
	print *,'Number of lines=',i,lfa
	lfa=i
	allocate(grid(lfa),iscc(lfa),ea(lfa,nh),profile(lfa),capa(lfa,2))
	profile=0
    ea=0.0
	rewind(10)
	read (10,*) cdum  ! header 1
	read (10,*) cdum  ! header 2
	do i=1,lfa
        read (10,*)iscc(i),grid(i),capa(i,1),(ea(i,j),j=1,nh),capa(i,2)
	end do
	close(10)
! READING  and findign profiles
	fname='scc-profile_pm25.csv'
	print *, 'Reading : ',trim(fname)
	open(unit=15,file=fname,status='old',action='read')
	read (15,*) cdum !header
	do
		read(15,*,END=200) isccf,cdum,j
		do i=1,lfa
		 if (isccf.eq.iscc(i)) profile(i)=j
		end do
	end do
200 continue
	do i=1,lfa
	 if(profile(i).eq.0) print *,'No profile: ',iscc(i),' ',i
	end do
	close(15)
	!print '(15I5)',(profile(i),i=1,lfa)
	print *,'Start count'	
	call count  ! counts the number of different profiles
	print *,'Finishing count'
! READING  and finding speciation for profiles
	fname='pm25_profiles.csv'
	print *, 'Reading : ',trim(fname)
	open(unit=16,file=fname,status='old',action='read')
	read(16,*)cdum
	read(16,*) nclass
	if(nclass.gt.5) stop "Change size in fagg dimension"
	rewind(16)
	allocate(cname(nclass))
	read(16,*)cdum
	read(16,*) nclass,(cname(i),i=1,nclass)
	!print *,nclass
	!print '(<nclass>(A,x))',cname
	allocate(fclass(size(prof2),nclass))
	do
		read(16,*,end=300,ERR=300)id,(fagg(j),j=1,nclass)
		do i=1,size(prof2)
		if(id.eq.prof2(i)) then
			do l=1,nclass
				fclass(i,l)=fagg(l)
			end do
		end if
		end do
	end do
300 continue
	!do i=1,size(prof2)
	!	print '(2i,<nclass>F)',prof2(i),i,(fclass(i,l),l=1,nclass)
	!end do
	close(16)
	return
end subroutine lee

subroutine calculos
implicit none
	integer i,j,k,l,ih
	integer ns,ng,ii
	print *,'Starting computations'
	allocate (emis(size(grid2),nclass,nh))
	emis=0
	ng =size(grid2)
	ns =size(prof2)
	do ii=1,lfa
	  do k=1,ng		! grid
		if(grid(ii).eq.grid2(k)) then
			do i=1,ns  !profiles
			if(prof2(i).eq.profile(ii)) then
					do l=1,nclass ! mechanism classes
					 do ih=1,nh   ! hours
	if(fclass(i,l).ne.0) emis(k,l,ih)=emis(k,l,ih)+fclass(i,l)*ea(ii,ih)
					 end do
					end do
			end if
			end do
		end if
	  end do
	end do

end subroutine calculos

subroutine guarda
implicit none
	integer i,j,k
    real suma
	character(len=20)::fname
	print *,maxval(emis),'Valor maximo'
	do j=1,size(emis,dim=2)
    suma=0.
	fname=trim(cname(j))//'_P.txt'
	open(unit=20,file=fname,action='write')
	write(20,'(A,A)')cname(j), 'Emissions'
	write(20,*) size(grid2),current_date,', ',cdia
		do k=1,size(emis,dim=1)
            if(emis(k,j,1).ne.0 .and. emis(k,j,12).ne.0 .and. emis(k,j,23).ne.0 )then
                write(20,200)grid2(k),capa(k,1),(emis(k,j,i),i=1,size(emis,dim=3)),capa(k,2)
                do i=1,size(emis,dim=3)
                    suma=suma+emis(k,j,i)
                end do
           end if
		end do
    write(6,*)cname(j),",",suma
	close(20)
	end do
200 format(I7,x,I3,x,<nh>(ES11.4,x),I3)
    print *,"*****  DONE PM2.5 POINT SPECIATION  *****"
end subroutine guarda
!                       _
!  ___ ___  _   _ _ __ | |_
! / __/ _ \| | | | '_ \| __|
!| (_| (_) | |_| | | | | |_
! \___\___/ \__,_|_| |_|\__|
subroutine count
	integer i,j,nn
	logical,allocatable::xl(:)
	nn=size(profile)
	allocate(xl(nn))
	xl=.true.
	do i=1,nn-1
		do j=i+1,nn
			if(profile(j).eq.profile(i).and.xl(j)) 	xl(j)=.false.
		end do
	end do
	j=0
	do i=1,nn
		if(xl(i)) j=j+1
	end do
	allocate(prof2(j),isp(j))
	j=0
	do i=1,nn
		if(xl(i)) then
		j=j+1
		prof2(j)=profile(i)
	end if
	end do
!
 print *,'Number different profiles',j !,prof2
!
  deallocate(xl)
  allocate(xl(size(iscc)))

  xl=.true.
  do i=1,lfa-1
   do j=i+1,lfa
   if(grid(j).eq.grid(i).and.xl(j)) xl(j)=.false.
   end do
  end do
  j=0
  do i=1,lfa
    if(xl(i)) j=j+1
  end do
  allocate(grid2(j))
  j=0
  do i=1,lfa
    if(xl(i)) then
	j=j+1
	grid2(j)=grid(i)
	end if
  end do

  print *,'Number of different cells',j
  deallocate(xl)
end subroutine count

end program pm25_speci_p
