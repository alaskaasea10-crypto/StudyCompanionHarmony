import { PageHeader } from '../components/PageHeader';
import { SectionSwitcher } from '../components/SectionSwitcher';
import { SquadMember } from '../models/StudyModels';
import { StudyPlanet } from '../components/StudyPlanet';
import { PlanetGrowth, PlanetGrowthService } from '../services/PlanetGrowthService';
import { formatSubjectName } from '../utils/SubjectDisplayName';

@Component
export struct GrowthPageView {
  @Prop planet: PlanetGrowth = PlanetGrowthService.calculate([], [], []);
  @State showPlanetRules: boolean = false;
  @State joinDialogOpen: boolean = false;
  @State leaveDialogOpen: boolean = false;
  @State joinCode: string = '';
  @State joinError: string = '';
  @Prop squadMessage: string = '';
  @Prop squadMembers: SquadMember[] = [];
  @Prop squadInviteCode: string = '';
  @Prop squadJoined: boolean = false;
  @Prop squadName: string = '';
  @Prop squadChallengeTitle: string = '';
  @Prop squadChallengeMinutes: number = 25;
  @Prop squadChallengeJoinedCount: number = 0;
  @Prop squadChallengeActive: boolean = false;
  onOpenFocus: () => void = () => {};
  onEncourageMember: (memberId: string) => void = () => {};
  onCreateInvite: () => void = () => {};
  onJoinTeam: (code: string) => void = () => {};
  onLeaveTeam: () => void = () => {};
  onCopyTeamCode: () => void = () => {};
  onBusinessOverlayChange: (visible: boolean) => void = () => {};
  onCreateChallenge: () => void = () => {};
  onOpenVideos: (moduleId: string) => void = () => {};

  private focusingCount(): number {
    return this.squadMembers.filter((member: SquadMember) =>
      member.status === '专注中' && member.isDemo !== true).length;
  }

  private realMemberCount(): number {
    return this.squadMembers.filter((member: SquadMember) => member.isDemo !== true).length;
  }

  private statusColor(status: string): string {
    if (status === '专注中') {
      return '#35C99A';
    }
    if (status === '休息中') {
      return '#F2A65A';
    }
    return '#A5A9BA';
  }

  private validJoinCode(): boolean {
    return /^[A-Za-z0-9-]{4,20}$/.test(this.joinCode.trim());
  }

  private submitJoin(): void {
    if (!this.validJoinCode()) {
      this.joinError = '请输入 4—20 位字母、数字或连字符';
      return;
    }
    this.onJoinTeam(this.joinCode.trim());
    this.joinDialogOpen = false;
    this.joinCode = '';
    this.joinError = '';
  }

  @Builder
  MemberCard(member: SquadMember) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Text(member.avatarText)
          .width(44).height(44).textAlign(TextAlign.Center)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .backgroundColor(member.accentColor).borderRadius(15)
        Column().width(11).height(11).borderRadius(6)
          .backgroundColor(this.statusColor(member.status))
          .border({ width: 2, color: Color.White })
      }.width(48).height(48)
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(member.isSelf ? `${member.name}（我）` : member.name)
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#25283A')
          if (member.isDemo) {
            Text('体验成员').fontSize(9).fontColor('#8A8FA2')
              .backgroundColor('#F0F1F6').padding({ left: 6, right: 6, top: 3, bottom: 3 }).borderRadius(8)
          }
        }.width('100%')
        Text(formatSubjectName(member.currentTask)).width('100%').fontSize(12).fontColor('#777C90').maxLines(1)
        Text(`${member.status} · 今日${member.todayMinutes}分钟 · 连续${member.streakDays}天`)
          .width('100%').fontSize(10).fontColor(this.statusColor(member.status))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (!member.isSelf) {
        Button(`微光 ${member.encouragementCount ?? 0}`)
          .height(34).fontSize(10).fontColor('#5B5FEF').backgroundColor('#EEEDFF').borderRadius(12)
          .onClick(() => {
            this.onEncourageMember(member.id);
          })
      }
    }
    .width('100%').padding(12).backgroundColor('#F7F8FC').borderRadius(16)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Scroll() {
        Column({ space: 16 }) {
          PageHeader({ icon: '🌱', title: '成长与小队', subtitle: '星球成长 · 校园服务' })
          SectionSwitcher({ selectedIndex: 1, firstTitle: '专注空间', secondTitle: '成长与小队',
            onChange: (index: number) => { if (index === 0) { this.onOpenFocus(); } } })
          Column({ space: 13 }) {
            Row({ space: 12 }) {
              StudyPlanet({ stage: this.planet.stage })
              Column({ space: 5 }) {
                Row() {
                  Text('星球').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#484073')
                  Blank()
                  Text('成长规则 ⓘ').fontSize(10).fontColor('#8E83AE')
                }.width('100%')
                Text(`Lv.${this.planet.level} · ${this.planet.title}`).fontSize(12).fontColor('#8E83AE')
                Progress({ value: this.planet.progress, total: 100, type: ProgressType.Linear })
                  .width('100%').color('#B2A1EC').backgroundColor('#E9E3F6').style({ strokeWidth: 4 })
                Text(`距离升级还差 ${this.planet.remaining} 点星光`).fontSize(10).fontColor('#8E83AE')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.width('100%').padding(12).backgroundColor('#F7F4FE').borderRadius(18)
              .onClick(() => { this.showPlanetRules = !this.showPlanetRules; })
            if (this.showPlanetRules) {
              Text('星球随你的本机档案成长：当天累计有一条至少 1 分钟的专注记录或答题记录，获得 10 点星光；与前一天连续学习再加 5 点。每天只奖励一次，每 100 点升一级。中断不降级；体验队友不计入。')
                .fontSize(11).lineHeight(18).fontColor('#8E83AE').width('100%')
            }
          }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

          Column({ space: 13 }) {
            if (!this.squadJoined) {
              Text('学习小队').width('100%').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#25283A')
              Text('和同学一起保持学习节奏').width('100%').fontSize(12).fontColor('#777C90')
              Button('加入小队').width('100%').height(42).fontSize(13)
                .backgroundColor('#5B5FEF').borderRadius(14)
                .onClick(() => {
                  this.joinDialogOpen = true;
                  this.joinError = '';
                  this.onBusinessOverlayChange(true);
                })
            } else {
              Text('我的小队').width('100%').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#25283A')
              Text(this.squadName.length > 0 ? this.squadName : '同航学习小队')
                .width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#484073')
              Row({ space: 10 }) {
                Column({ space: 3 }) {
                  Text('小队口令').fontSize(10).fontColor('#8A8FA2')
                  Text(this.squadInviteCode).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button('复制').height(34).fontSize(11).fontColor('#5B5FEF')
                  .backgroundColor('#EEEDFF').borderRadius(11).onClick(() => { this.onCopyTeamCode(); })
              }.width('100%').padding(12).backgroundColor('#F7F8FC').borderRadius(14)
              ForEach(this.squadMembers, (member: SquadMember) => { this.MemberCard(member) },
                (member: SquadMember) => `${member.id}-${member.encouragementCount ?? 0}-${member.status}-${member.todayMinutes}`)
              if (this.squadChallengeActive) {
                Row({ space: 10 }) {
                  Text('⚡').fontSize(22)
                  Column({ space: 3 }) {
                    Text(this.squadChallengeTitle).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#25283A')
                    Text(`${this.squadChallengeMinutes}分钟 · 本机体验挑战`)
                      .fontSize(10).fontColor('#777C90')
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Text('进行中').fontSize(10).fontColor('#35A982')
                }.width('100%').padding(12).backgroundColor('#EAF8F3').borderRadius(15)
              }
              Button(this.squadChallengeActive ? '再次发起挑战' : `发起${this.squadChallengeMinutes}分钟挑战`)
                .width('100%').height(40).fontSize(12).backgroundColor('#24213F').borderRadius(14)
                .onClick(() => { this.onCreateChallenge(); })
              Text(this.squadMessage).width('100%').fontSize(12).fontColor('#5F6478')
              Text('当前小队加入、成员与挑战状态仅保存在本机；体验成员不代表实时同步。')
                .width('100%').fontSize(10).fontColor('#A0A4B4').lineHeight(16)
              Button('退出小队').height(36).fontSize(11).fontColor('#8B6470')
                .backgroundColor(Color.Transparent).onClick(() => {
                  this.leaveDialogOpen = true;
                  this.onBusinessOverlayChange(true);
                })
            }
          }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

          Column({ space: 13 }) {
            Text('校园与职业助手').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
            Text('知识补给 · 自由选课，在原平台观看').width('100%').fontSize(12).fontColor('#9397A9')
            Row({ space: 10 }) {
              Column({ space: 5 }) { Text('🏠').fontSize(24); Text('租房避坑').fontSize(13).fontWeight(FontWeight.Bold); Text('房源与租赁知识 ›').fontSize(11).fontColor('#9397A9') }
                .layoutWeight(1).padding(13).backgroundColor('#FFF4EA').borderRadius(15).onClick(() => { this.onOpenVideos('housing'); })
              Column({ space: 5 }) { Text('💼').fontSize(24); Text('职业规划').fontSize(13).fontWeight(FontWeight.Bold); Text('方向与求职课程 ›').fontSize(11).fontColor('#9397A9') }
                .layoutWeight(1).padding(13).backgroundColor('#EEF3FF').borderRadius(15).onClick(() => { this.onOpenVideos('career'); })
            }.width('100%')
            Row({ space: 10 }) {
              Column({ space: 5 }) { Text('🏥').fontSize(24); Text('医保报销').fontSize(13).fontWeight(FontWeight.Bold); Text('官方科普视频 ›').fontSize(11).fontColor('#9397A9') }
                .layoutWeight(1).padding(13).backgroundColor('#EAF8F3').borderRadius(15).onClick(() => { this.onOpenVideos('insurance'); })
              Column({ space: 5 }) { Text('📄').fontSize(24); Text('合同检查').fontSize(13).fontWeight(FontWeight.Bold); Text('签约常识与案例 ›').fontSize(11).fontColor('#9397A9') }
                .layoutWeight(1).padding(13).backgroundColor('#F6EEFF').borderRadius(15).onClick(() => { this.onOpenVideos('contract'); })
            }.width('100%')
          }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)
        }.width('100%').padding(20)
      }.width('100%').height('100%')

      if (this.joinDialogOpen) {
        Column().width('100%').height('100%').backgroundColor('#730D1020').hitTestBehavior(HitTestMode.Block)
        Column({ space: 14 }) {
          Text('加入学习小队').width('100%').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#25283A')
          Text('输入同学分享的小队口令').width('100%').fontSize(12).fontColor('#777C90')
          TextInput({ placeholder: '小队口令', text: this.joinCode }).width('100%').height(46)
            .backgroundColor('#F4F3FA').borderRadius(13).onChange((value: string) => { this.joinCode = value; this.joinError = ''; })
          if (this.joinError.length > 0) { Text(this.joinError).width('100%').fontSize(11).fontColor('#C4515D') }
          Row({ space: 9 }) {
            Button('取消').layoutWeight(1).height(40).fontSize(12).fontColor('#6865D9').backgroundColor('#EFEEFA').borderRadius(13)
              .onClick(() => {
                this.joinDialogOpen = false;
                this.joinCode = '';
                this.joinError = '';
                this.onBusinessOverlayChange(false);
              })
            Button('加入小队').layoutWeight(1).height(40).fontSize(12).backgroundColor('#5B5FEF').borderRadius(13)
              .onClick(() => {
                if (this.validJoinCode()) { this.onBusinessOverlayChange(false); }
                this.submitJoin();
              })
          }.width('100%')
        }.width('84%').padding(20).backgroundColor(Color.White).borderRadius(22)
          .shadow({ radius: 28, color: '#44252A4A', offsetX: 0, offsetY: 10 }).hitTestBehavior(HitTestMode.Default)
      }
      if (this.leaveDialogOpen) {
        Column().width('100%').height('100%').backgroundColor('#730D1020').hitTestBehavior(HitTestMode.Block)
        Column({ space: 14 }) {
          Text('退出学习小队？').width('100%').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#25283A')
          Text('退出后将不再显示当前小队信息。').width('100%').fontSize(12).fontColor('#777C90')
          Row({ space: 9 }) {
            Button('取消').layoutWeight(1).height(40).fontSize(12).fontColor('#6865D9').backgroundColor('#EFEEFA').borderRadius(13)
              .onClick(() => { this.leaveDialogOpen = false; this.onBusinessOverlayChange(false); })
            Button('确认退出').layoutWeight(1).height(40).fontSize(12).backgroundColor('#8B6470').borderRadius(13)
              .onClick(() => {
                this.onLeaveTeam();
                this.leaveDialogOpen = false;
                this.onBusinessOverlayChange(false);
              })
          }.width('100%')
        }.width('84%').padding(20).backgroundColor(Color.White).borderRadius(22)
          .shadow({ radius: 28, color: '#44252A4A', offsetX: 0, offsetY: 10 }).hitTestBehavior(HitTestMode.Default)
      }
    }.width('100%').layoutWeight(1)
  }
}
