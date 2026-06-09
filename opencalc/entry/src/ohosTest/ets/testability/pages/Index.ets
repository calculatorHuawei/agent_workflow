import { TestRunner } from '@ohos/hypium'

@Entry
@Component
struct Index {
  @State message: string = 'Running tests...'

  aboutToAppear() {
    console.log('Test page appearing')
  }

  build() {
    Column() {
      Text(this.message)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 40 })
    }
    .width('100%')
    .height('100%')
  }
}
