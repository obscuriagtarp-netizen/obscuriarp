import { useMenuData } from '@/stores/data'

export default function () {
  const menuData = useMenuData()

  window.addEventListener('message', ({ data }) => {
    switch (data.action) {
      case 'openMenu':
        menuData.toggleMenu(true)
        break

      case 'refreshMembers':
        menuData.setMembers(data.members)
        break

      case 'leaveChannel':
        menuData.disconnectRadio()
        break

      case 'startCracking':
        menuData.startCracking(data.hackTime)
        break

      case 'startExam':
        menuData.setQuestions(data.questions)
        break

      default:
        break
    }
  })
}
